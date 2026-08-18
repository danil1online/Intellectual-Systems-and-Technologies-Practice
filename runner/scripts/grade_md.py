#!/usr/bin/env python3
"""
grade_md.py — Оценка Markdown-отчёта студента через LLM.

Для MD-only работ (Pr_1, Pr_4, Pr_22..Pr_28 и остальных практик, где выбран .md-отчёт).
Анализирует git log репозитория + содержимое md-отчёта.
Шкала: 0-5.

Использование:
    grade_md.py <repo_dir> <practice_number> [md_file]
"""

import os
import sys
import json
import datetime
import subprocess
import requests
from pathlib import Path

from grading_common import (
    read_requirement_text,
    extract_control_questions,
    format_question_block,
    normalize_grade_payload,
    parse_llm_json,
    llm_raw_preview,
)

# Конфигурация LLM
LLM_BASE_URL = os.environ.get("LLM_CI_BASE_URL", "http://llm:8080/v1")
LLM_API_KEY = os.environ.get("LLM_CI_API_KEY", "local-api-key")
LLM_MODEL = os.environ.get("LLM_CI_MODEL", "gpt-4o")

# Критерии для каждой практики
PRACTICE_CHECKLIST = {
    1: [
        "Создана ветка (branch)",
        "Переключение на ветку (checkout)",
        "Создание и добавление файла (add)",
        "Фиксация изменений (commit)",
        "Откат изменений (revert)",
        "Слияние ветки (merge)",
        "Отправка на сервер (push)",
        "Удаление ветки (branch -d)",
    ],
}


def get_git_log(repo_dir):
    """Получить историю коммитов и веток."""
    result = {
        "commits": [],
        "branches": [],
        "remote": None,
    }

    try:
        # Получаем историю коммитов
        res = subprocess.run(
            ["git", "log", "--all", "--oneline", "--graph"],
            cwd=repo_dir, capture_output=True, text=True, timeout=10
        )
        if res.returncode == 0:
            result["commits"] = res.stdout.strip().split("\n")

        # Получаем ветки
        res = subprocess.run(
            ["git", "branch", "-a"],
            cwd=repo_dir, capture_output=True, text=True, timeout=10
        )
        if res.returncode == 0:
            result["branches"] = [b.strip() for b in res.stdout.strip().split("\n") if b.strip()]

        # Получаем remote
        res = subprocess.run(
            ["git", "remote", "-v"],
            cwd=repo_dir, capture_output=True, text=True, timeout=10
        )
        if res.returncode == 0:
            result["remote"] = res.stdout.strip()

    except Exception as e:
        result["error"] = str(e)

    return result


def get_md_content(md_file):
    """Прочитать содержимое md-отчёта."""
    try:
        with open(md_file, "r", encoding="utf-8") as f:
            return f.read()
    except Exception:
        return ""


def build_prompt(git_log, md_content, practice_num, requirement_text=None, questions=None):
    """Промпт для оценки. Если передан requirement-док — оцениваем
    соответствие именно этому требованию; если есть questions — отдельный блок
    контрольных вопросов оценивается бинарно: каждый вопрос 0 или полный вес."""
    questions = questions or []
    git_summary = ""
    if git_log.get("error"):
        git_summary = f"Ошибка чтения git: {git_log['error']}"
    else:
        commits = git_log.get("commits", [])
        git_summary = f"Коммитов: {len(commits)}\nВеток: {len(git_log.get('branches', []))}\n"
        for line in commits[:15]:
            git_summary += f"  {line}\n"
        for branch in git_log.get("branches", [])[:10]:
            git_summary += f"  Branch: {branch}\n"
        if git_log.get("remote"):
            git_summary += f"\nRemotes:\n{git_log['remote']}\n"

    md_preview = md_content[:12000] if md_content else "(файл отчёта не найден или пуст)"
    requirement_preview = (requirement_text or "")[:30000]

    if requirement_text or questions:
        prompt = f"""Ты — строгий преподаватель курса ISTP (интеллектуальные системы и технологии).
Оцени работу студента по ПРАКТИКЕ {practice_num}.

=== ТРЕБОВАНИЯ ПО ПРАКТИКЕ (docs/Pr_{practice_num}.md) ===
{requirement_preview or "(requirement-файл не найден)"}

В requirement-документе могут встречаться скрытые эталонные ответы в HTML-комментариях <!-- ANSWER ... -->. Используй их как критерий правильности решений/выводов, но не раскрывай их дословно в feedback студенту.

=== ДЕЙСТВИЯ СТУДЕНТА (git log) ===
{git_summary}

=== СОДЕРЖИМОЕ ОТЧЁТА СТУДЕНТА ===
{md_preview}

ЗАДАЧА: оцени, насколько выполненные действия студента СОТВЕТСТВУЮТ ТРЕБОВАНИЯМ.
Оцени отдельно:
1) техническую/практическую часть работы (task_score 0..3);
2) наличие ответов на контрольные вопросы, если раздел «КОНТРОЛЬНЫЕ ВОПРОСЫ» присутствует.

Шкала task_score:
3 — ключевые шаги практики выполнены, работа соответствует методичке;
2 — выполнено в основном, есть незначительные пробелы;
1 — выполнено меньше половины ключевых шагов;
0 — работа фактически не представлена или не соответствует практике.

"""
        if questions:
            prompt += f"""=== КОНТРОЛЬНЫЕ ВОПРОСЫ ({len(questions)}) ===
{format_question_block(questions)}

По каждому контрольному вопросу ставь true только если в отчёте/действиях есть внятный ответ по смыслу.
Итоговый балл посчитать НЕ нужно — его посчитает код.
Отвечай ТОЛЬКО одним JSON-объектом, без markdown, без пояснений до/после.
Формат:
{{"task_score": <0-3>, "control_questions": [<true/false>, ...], "feedback": "<1-2 предложения>", "issues": ["..."], "recommendations": ["..."]}}
В массиве control_questions ровно {len(questions)} значений.
"""
        else:
            prompt += """Шкала итога (0-5):
5 — все требования полностью выполнены
4 — выполнено в основном, есть незначительные пробелы
3 — выполнено больше половины требований
2 — выполнено меньше половины
1 — выполнено меньше 20%
0 — не выполнялось
Отвечай ТОЛЬКО одним JSON-объектом, без markdown, без пояснений до/после.
Формат:
{"score": <0-5>, "feedback": "<1-2 предложения>", "issues": ["..."], "recommendations": ["..."]}
"""
        return prompt

    # Fallback: чеклист операций (когда requirement-док не передан)
    checklist = PRACTICE_CHECKLIST.get(practice_num, [])
    prompt = f"""Оцени практическую работу студента по Git.

Информация о репозитории (git log):
{git_summary}

Содержимое отчёта (Pr_{practice_num}.md):
{md_preview}

Требуемые операции для Pr_{practice_num}:
{chr(10).join(f'- {i+1}. {op}' for i, op in enumerate(checklist))}

Шкала оценки (0-5):
5 — все операции выполнены верно
4 — выполнено с несколькими ошибками
3 — выполнено не полностью, но основное
2 — выполнено меньше половины
1 — выполнено меньше 20%
0 — не выполнялось

 Отвечай ТОЛЬКО одним JSON-объектом, без markdown, без пояснений до/после.
 Формат:
 {{
     "score": число от 0 до 5,
     "feedback": "детальный отзыв",
     "issues": ["список проблем"],
     "recommendations": ["список рекомендаций"]
 }}
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
            {"role": "system", "content": "Ты — строгий преподаватель. Оцениваешь практические работы по Git."},
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
                "score": 0,
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
            "score": 0,
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

    if len(args) < 2:
        print("Usage: grade_md.py <repo_dir> <practice_number> [md_file] [--requirement <path>]")
        sys.exit(1)

    repo_dir = args[0]
    practice_num = int(args[1])
    md_file = args[2] if len(args) > 2 else None

    print(f"Оцениваю Pr_{practice_num} в репозитории: {repo_dir}")
    if requirement:
        print(f"  requirement-док: {requirement}")

    requirement_text = read_requirement_text(requirement) if requirement else ""
    questions = extract_control_questions(requirement_text)
    if questions:
        print(f"  контрольных вопросов: {len(questions)}")

    # Читаем git log
    git_log = get_git_log(repo_dir)

    # Читаем md-файл
    if md_file and os.path.exists(md_file):
        md_content = get_md_content(md_file)
    else:
        # Ищем Pr_*.md в репозитории
        md_files = list(Path(repo_dir).rglob("Pr_*.md"))
        if md_files:
            md_file = str(md_files[0])
            md_content = get_md_content(md_file)
            print(f"  Найден отчёт: {md_file}")
        else:
            md_content = ""
            print("  ⚠ Отчёт .md не найден")

    # Формируем промпт
    prompt = build_prompt(
        git_log,
        md_content,
        practice_num,
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

    # Формируем отчёт
    report = {
        "timestamp": datetime.datetime.now().isoformat(),
        "practice": practice_num,
        "notebook": None,
        "cells_analyzed": 0,
        "code_cells": 0,
        "markdown_cells": 0,
        "git_commits": len(git_log.get("commits", [])),
        "git_branches": len(git_log.get("branches", [])),
        "practice_requirement": requirement or "",
        "question_count": len(questions),
        **result,
    }

    output_path = "ai_report.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print(f"Оценка: {result.get('score', 'N/A')}/5")
    print(f"Отчёт сохранён: {output_path}")


if __name__ == "__main__":
    main()
