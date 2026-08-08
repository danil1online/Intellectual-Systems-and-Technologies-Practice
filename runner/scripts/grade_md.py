#!/usr/bin/env python3
"""
grade_md.py — Оценка Markdown-отчёта студента через LLM.

Для terminal-based работ (Pr_1, Pr_2).
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


def build_prompt(git_log, md_content, practice_num):
    """Сформировать промпт для оценки."""
    checklist = PRACTICE_CHECKLIST.get(practice_num, [])

    git_summary = ""
    if git_log.get("error"):
        git_summary = f"Ошибка чтения git: {git_log['error']}"
    else:
        git_summary = f"Коммитов: {len(git_log.get('commits', []))}\nВеток: {len(git_log.get('branches', []))}\n"
        for line in git_log.get("commits", [])[:10]:
            git_summary += f"  {line}\n"
        for branch in git_log.get("branches", []):
            git_summary += f"  Branch: {branch}\n"

    md_preview = md_content[:2000] if md_content else "(файл не найден или пуст)"

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

Отвечай СТРОГО в формате JSON:
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

        # Убираем markdown code block если есть
        if content.startswith("```"):
            content = content.split("\n", 1)[-1]
            if content.endswith("```"):
                content = content.rsplit("\n", 1)[0]

        return json.loads(content)

    except json.JSONDecodeError:
        return {
            "score": 0,
            "feedback": "Ошибка парсинга ответа LLM",
            "issues": ["Ошибка оценки"],
            "recommendations": [],
        }
    except Exception as e:
        return {
            "score": 0,
            "feedback": f"Ошибка связи с LLM: {e}",
            "issues": [f"Ошибка LLM: {e}"],
            "recommendations": [],
        }


def main():
    if len(sys.argv) < 3:
        print("Usage: grade_md.py <repo_dir> <practice_number> [md_file]")
        sys.exit(1)

    repo_dir = sys.argv[1]
    practice_num = int(sys.argv[2])
    md_file = sys.argv[3] if len(sys.argv) > 3 else None

    print(f"Оцениваю Pr_{practice_num} в репозитории: {repo_dir}")

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
    prompt = build_prompt(git_log, md_content, practice_num)
    result = evaluate_with_llm(prompt)

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
        **result,
    }

    output_path = "ai_report.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print(f"Оценка: {result.get('score', 'N/A')}/5")
    print(f"Отчёт сохранён: {output_path}")


if __name__ == "__main__":
    main()
