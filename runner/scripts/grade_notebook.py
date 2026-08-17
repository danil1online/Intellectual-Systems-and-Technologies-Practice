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
)

# Конфигурация LLM
LLM_BASE_URL = os.environ.get("LLM_CI_BASE_URL", "http://llm:8080/v1")
LLM_API_KEY = os.environ.get("LLM_CI_API_KEY", "local-api-key")
LLM_MODEL = os.environ.get("LLM_CI_MODEL", "gpt-4o")


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
Отвечай СТРОГО в формате JSON:
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
Отвечай СТРОГО JSON:
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
Отвечай СТРОГО JSON:
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

        # Убираем markdown code block если есть
        if content.startswith("```"):
            content = content.split("\n", 1)[-1]
            if content.endswith("```"):
                content = content.rsplit("\n", 1)[0]

        return json.loads(content)

    except json.JSONDecodeError:
        return {
            "executes": False,
            "has_explanation": False,
            "score": 0,
            "grade": "F",
            "feedback": "Ошибка парсинга ответа LLM",
            "issues": ["Ошибка оценки"],
            "recommendations": [],
        }
    except Exception as e:
        return {
            "executes": False,
            "has_explanation": False,
            "score": 0,
            "grade": "F",
            "feedback": f"Ошибка связи с LLM: {e}",
            "issues": [f"Ошибка LLM: {e}"],
            "recommendations": [],
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

    # Оценка через LLM
    prompt = build_evaluation_prompt(
        cells,
        requirement_text=requirement_text,
        questions=questions,
    )
    result = evaluate_with_llm(prompt)

    if questions:
        result, _ = normalize_grade_payload(result, questions)

    try:
        result["score"] = int(result.get("score", 0) or 0)
    except (TypeError, ValueError):
        result["score"] = 0
    if "feedback" not in result:
        result["feedback"] = result.get("comment", "")

    # Формируем финальный отчёт
    report = {
        "timestamp": datetime.datetime.now().isoformat(),
        "notebook": os.path.basename(notebook_path),
        "cells_analyzed": len(cells),
        "code_cells": len([c for c in cells if c["type"] == "code"]),
        "markdown_cells": len([c for c in cells if c["type"] == "markdown"]),
        "practice_requirement": requirement or "",
        "question_count": len(questions),
        **result,
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print(f"Оценка: {report.get('score', 'N/A')}/5")
    print(f"Отчёт сохранён: {output_path}")


if __name__ == "__main__":
    main()
