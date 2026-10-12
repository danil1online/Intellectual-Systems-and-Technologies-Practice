#!/usr/bin/env python3
"""
grade_notebook.py — Оценка ноутбука студента через LLM.

Использует LLM-эндпоинт для проверки:
1. Выполняется ли код
2. Правильны ли результаты
3. Есть ли комментарии и объяснения
4. Соответствует ли заданию

Результат: ai_report.json
"""

import os
import re
import sys
import json
import datetime
import nbformat
import requests
from pathlib import Path

from grading_common import (
    read_requirement_text,
    extract_control_questions,
    format_question_block,
    normalize_grade_payload,
    parse_llm_json,
    llm_raw_preview,
    build_spec_prompt,
    normalize_spec_payload,
    evaluate_with_llm_spec,
    load_ideal_report,
)
from practice_specs import PRACTICE_SPECS

# Конфигурация LLM
LLM_BASE_URL = os.environ.get("LLM_CI_BASE_URL", "http://llm:8080/v1")
LLM_API_KEY = os.environ.get("LLM_CI_API_KEY", "local-api-key")
LLM_MODEL = os.environ.get("LLM_CI_MODEL", "model.gguf")


def load_notebook(filepath):
    """Загрузить ноутбук и извлечь код и markdown."""
    with open(filepath, "r", encoding="utf-8") as f:
        nb = nbformat.read(f, as_version=4)

    cells = []
    for cell in nb.cells:
        if cell.cell_type == "code":
            cells.append({
                "type": "code",
                "source": cell.source,
                "outputs": cell.outputs if hasattr(cell, "outputs") else []
            })
        elif cell.cell_type == "markdown":
            cells.append({
                "type": "markdown",
                "source": cell.source
            })

    return nb, cells


def _output_text(output):
    """Текст одного output ячейки (stream/execute_result/display_data/error)."""
    if not isinstance(output, dict):
        return ""
    otype = output.get("output_type")
    if otype == "stream":
        text = output.get("text", "")
        return "".join(text) if isinstance(text, list) else str(text)
    if otype in ("execute_result", "display_data"):
        data = output.get("data") or {}
        for key in ("text/plain", "text/html"):
            value = data.get(key)
            if value:
                return "".join(value) if isinstance(value, list) else str(value)
        return ""
    if otype == "error":
        traceback = output.get("traceback") or [f"{output.get('ename')}: {output.get('evalue')}"]
        return "\n".join(traceback)
    return ""


def notebook_to_report_text(cells, max_output_chars=500, max_md_chars=3000):
    """Ноутбук → плоский текст для spec-промпта и grounding.

    Код ячеек + текстовые output'ы (обрезка на ячейку) + markdown-ячейки как
    есть: заголовки ответов («Контрольные вопросы»/«Ответы на контрольные
    вопросы») остаются целыми строками — от этого зависит разбор блока
    ответов в normalize_spec_payload.
    """
    parts = []
    code_idx = 0
    md_idx = 0
    for cell in cells:
        if cell["type"] == "code":
            code_idx += 1
            block = f"--- Ячейка кода {code_idx} ---\n{cell['source'].strip()}\n"
            outputs = []
            for output in cell.get("outputs", []):
                text = _output_text(output).strip()
                if not text:
                    continue
                if len(text) > max_output_chars:
                    text = text[:max_output_chars] + " …[обрезано]"
                outputs.append(f"[вывод] {text}")
            if outputs:
                block += "\n".join(outputs) + "\n"
            parts.append(block)
        else:
            md_idx += 1
            source = cell["source"].strip()[:max_md_chars]
            parts.append(f"--- Ячейка Markdown {md_idx} ---\n{source}\n")
    return "\n".join(parts)


def build_evaluation_prompt(cells, requirement_text=None, questions=None):
    """Промпт для оценки ноутбука. Если requirement-док передан — оцениваем
    соответствие ему; если есть questions — отдельно проверяем ответы."""
    questions = questions or []
    code_cells = [c for c in cells if c["type"] == "code"]
    md_cells = [c for c in cells if c["type"] == "markdown"]

    code_summary = ""
    total_chars = 0
    for i, cell in enumerate(code_cells):
        snippet = cell['source'][:1500]
        block = f"\n--- Ячейка кода {i + 1} ---\n{snippet}\n"
        if total_chars + len(block) > 24000:
            break
        code_summary += block
        total_chars += len(block)

    md_summary = ""
    total_chars = 0
    for i, cell in enumerate(md_cells):
        snippet = cell['source'][:2000]
        block = f"\n--- Ячейка Markdown {i + 1} ---\n{snippet}\n"
        if total_chars + len(block) > 12000:
            break
        md_summary += block
        total_chars += len(block)

    has_output = any(len(c.get("outputs", [])) > 0 for c in code_cells)

    if requirement_text or questions:
        prompt = f"""Ты — строгий преподаватель курса ISTP (интеллектуальные системы и технологии).

Оцени работу студента в Jupyter-ноутбуке по заданному требованию.

=== КОД СТУДЕНТА ===
{code_summary}

=== Markdown-пояснения ===
{md_summary}

=== ТРЕБОВАНИЯ ПО ПРАКТИКЕ ===
{(requirement_text or '')[:30000] or '(requirement-файл не найден)'}

В requirement-документе могут встречаться скрытые эталонные ответы в HTML-комментариях <!-- ANSWER ... -->. Используй их как критерий правильности решений/выводов, но не раскрывай их дословно в feedback студенту.

ИНФОРМАЦИЯ:
- Всего ячеек кода: {len(code_cells)}
- Всего Markdown-ячеек: {len(md_cells)}
- Есть output'ы: {'Да' if has_output else 'Нет'}

ЗАДАЧА: оцени выполнение практической части (task_score 0..3).
3 — ключевые шаги практики выполнены, результаты и пояснения соответствуют методичке;
2 — выполнено в основном, есть незначительные пробелы;
1 — выполнено меньше половины ключевых шагов;
0 — работа фактически не представлена или не соответствует практике.

"""
        if questions:
            prompt += f"""=== КОНТРОЛЬНЫЕ ВОПРОСЫ ({len(questions)}) ===
{format_question_block(questions)}

По каждому контрольному вопросу ставь true только если в markdown-ячейках/коде/выводах есть внятный ответ по смыслу.
Итоговый балл посчитать НЕ нужно — его посчитает код.
Отвечай ТОЛЬКО одним JSON-объектом, без markdown, без пояснений до/после.
Формат:
{{"task_score": <0-3>, "control_questions": [<true/false>, ...], "feedback": "<1-2 предложения>", "issues": ["..."], "recommendations": ["..."]}}
В массиве control_questions ровно {len(questions)} значений.
"""
        else:
            prompt += """Шкала итога (0-5):
5 — все задания выполнены, код работает, есть пояснения
4 — выполнено с небольшими ошибками
3 — выполнено не полностью, но основное есть
2 — выполнено меньше половины
1 — выполнено меньше 20%
0 — не выполнялось
Отвечай ТОЛЬКО одним JSON-объектом, без markdown, без пояснений до/после.
Формат:
{"executes": true/false, "has_explanation": true/false, "score": <0-5>, "feedback": "<1-2 предложения>", "issues": ["..."], "recommendations": ["..."]}
"""
        return prompt

    prompt = f"""Ты — строгий преподаватель курса ISTP. Оцени Jupyter Notebook студента по общим критериям.

=== КОД СТУДЕНТА ===
{code_summary}

=== Markdown-пояснения ===
{md_summary}

Исполнение кода: {'Выполнялся (есть вывод)' if has_output else 'НЕ выполнялся (нет вывода в ячейках)'}

Шкала 0-5:
5 — все задания выполнены, код работает, есть пояснения
4 — выполнено с небольшими ошибками
3 — выполнено не полностью, но основное есть
 2 — выполнено меньше половины
 1 — выполнено меньше 20%
 0 — не выполнялось
 Отвечай ТОЛЬКО одним JSON-объектом, без markdown, без пояснений до/после.
 Формат:
 {{"executes": true/false, "has_explanation": true/false, "score": <0-5>, "feedback": "<1-2 предложения>", "issues": ["..."], "recommendations": ["..."]}}
 """
    return prompt


def evaluate_with_llm(prompt):
    """Отправить промпт в LLM и получить оценку."""
    headers = {
        "Authorization": f"Bearer {LLM_API_KEY}",
        "Content-Type": "application/json",
    }

    data = {
        "model": LLM_MODEL,
        "messages": [
            {"role": "system", "content": "Ты — строгий преподаватель. Оцениваешь ноутбуки студентов."},
            {"role": "user", "content": prompt},
        ],
        "temperature": 0.1,
        "max_tokens": 2048,
    }

    try:
        response = requests.post(f"{LLM_BASE_URL}/chat/completions", json=data, headers=headers, timeout=180)
        response.raise_for_status()

        content = response.json()["choices"][0]["message"]["content"]
        parsed, parse_mode = parse_llm_json(content)

        if not parsed:
            preview = llm_raw_preview(content)
            print(
                f"LLM parse failed (mode={parse_mode}); raw_preview={preview[:500]!r}",
                file=sys.stderr,
            )
            return {
                "executes": False,
                "has_explanation": False,
                "score": 0,
                "grade": "F",
                "feedback": "Ошибка парсинга ответа LLM",
                "issues": ["Ошибка оценки"],
                "recommendations": [],
                "llm_parse_mode": parse_mode,
                "llm_raw_preview": preview,
            }

        parsed.setdefault("issues", [])
        parsed.setdefault("recommendations", [])
        if parse_mode != "strict":
            parsed["llm_raw_preview"] = llm_raw_preview(content)
        parsed["llm_parse_mode"] = parse_mode
        return parsed

    except Exception as e:
        return {
            "executes": False,
            "has_explanation": False,
            "score": 0,
            "grade": "F",
            "feedback": f"Ошибка связи с LLM: {e}",
            "issues": [f"Ошибка LLM: {e}"],
            "recommendations": [],
            "llm_parse_mode": "request-error",
        }


def main():
    args = sys.argv[1:]
    requirement = None
    if "--requirement" in args:
        idx = args.index("--requirement")
        if idx + 1 < len(args):
            requirement = args[idx + 1]
        del args[idx:idx + 2]

    if len(args) < 1:
        print("Usage: grade_notebook.py <notebook.ipynb> [output.json] [--requirement <path>]")
        sys.exit(1)

    notebook_path = args[0]
    output_path = args[1] if len(args) > 1 else "ai_report.json"

    print(f"Оцениваю: {notebook_path}")
    if requirement:
        print(f"  requirement-док: {requirement}")

    requirement_text = read_requirement_text(requirement) if requirement else ""
    questions = extract_control_questions(requirement_text)
    if questions:
        print(f"  контрольных вопросов: {len(questions)}")

    # Загрузка ноутбука
    try:
        nb, cells = load_notebook(notebook_path)
    except Exception as e:
        report = {
            "error": str(e),
            "timestamp": datetime.datetime.now().isoformat(),
            "score": 0,
            "grade": "F",
        }
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        print(f"Ошибка загрузки ноутбука: {e}")
        return

    # Номер практики — из имени файла (deliverables по конвенции Pr_<N>_*.ipynb)
    practice_num = None
    m = re.match(r"^Pr_(\d+)_", os.path.basename(notebook_path))
    if m:
        practice_num = int(m.group(1))
    spec = PRACTICE_SPECS.get(practice_num) if practice_num else None

    if spec:
        # Spec-путь: компактный чек-лист, баллы считает код (grounding из текста ноутбука)
        report_text = notebook_to_report_text(cells)
        if not report_text.strip():
            result = {
                "score": 0,
                "feedback": "Ноутбук пуст",
                "issues": ["В ноутбуке нет кода и markdown"],
                "recommendations": [
                    f"Заполните ноутбук Pr_{practice_num}_report.ipynb (ячейки с кодом заданий)",
                ],
            }
            grading_mode = "spec-no-report"
        else:
            print(
                f"  spec-оценка: {len(spec['tasks'])} шагов задания, "
                f"{len(spec.get('questions', []))} контрольных вопросов"
            )
            prompt = build_spec_prompt(
                spec, practice_num, report_text,
                ideal_report=load_ideal_report(practice_num),
                reference_position="before",
            )
            result, meta = evaluate_with_llm_spec(prompt, spec, LLM_BASE_URL, LLM_API_KEY, LLM_MODEL)
            for key, value in meta.items():
                result.setdefault(key, value)
            result = normalize_spec_payload(result, spec, report_text)
            grading_mode = "spec"
    else:
        # Legacy-путь: вся методичка в промпт (практики без spec)
        prompt = build_evaluation_prompt(
            cells,
            requirement_text=requirement_text,
            questions=questions,
        )
        result = evaluate_with_llm(prompt)

        if questions:
            result, _ = normalize_grade_payload(result, questions)
        grading_mode = "legacy"

    try:
        result["score"] = int(result.get("score", 0) or 0)
    except (TypeError, ValueError):
        result["score"] = 0
    if "feedback" not in result:
        result["feedback"] = result.get("comment", "")

    # Формируем финальный отчёт
    report = {
        "timestamp": datetime.datetime.now().isoformat(),
        "practice": practice_num,
        "notebook": os.path.basename(notebook_path),
        "cells_analyzed": len(cells),
        "code_cells": len([c for c in cells if c["type"] == "code"]),
        "markdown_cells": len([c for c in cells if c["type"] == "markdown"]),
        "grading_mode": grading_mode,
        "practice_requirement": requirement or "",
        "question_count": len(spec.get("questions", [])) if spec else len(questions),
        **result,
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print(f"Оценка: {report.get('score', 'N/A')}/5")
    print(f"Отчёт сохранён: {output_path}")


if __name__ == "__main__":
    main()
