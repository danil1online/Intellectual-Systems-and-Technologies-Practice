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


def build_evaluation_prompt(cells):
    """Сформировать промпт для оценки ноутбука."""
    code_cells = [c for c in cells if c["type"] == "code"]
    md_cells = [c for c in cells if c["type"] == "markdown"]

    code_summary = ""
    for i, cell in enumerate(code_cells):
        code_summary += f"\n--- Ячейка кода {i+1} ---\n{cell['source'][:500]}\n"

    md_summary = ""
    for i, cell in enumerate(md_cells):
        md_summary += f"\n--- Ячейка Markdown {i+1} ---\n{cell['source'][:500]}\n"

    has_output = any(len(c.get("outputs", [])) > 0 for c in code_cells)

    prompt = f"""Оцени Jupyter Notebook студента по следующим критериям:

1. {code_summary}

Markdown пояснения:{md_summary}

Исполнение кода: {'Есть вывод' if has_output else 'Нет вывода'}

Отвечай в формате JSON:
{{
    "executes": true/false,
    "has_explanation": true/false,
    "score": число от 0 до 100,
    "grade": "A"|"B"|"C"|"D"|"F",
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
    if len(sys.argv) < 2:
        print("Usage: grade_notebook.py <notebook.ipynb> [output.json]")
        sys.exit(1)

    notebook_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else "ai_report.json"

    print(f"Оцениваю: {notebook_path}")

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
    prompt = build_evaluation_prompt(cells)
    result = evaluate_with_llm(prompt)

    # Формируем финальный отчёт
    report = {
        "timestamp": datetime.datetime.now().isoformat(),
        "notebook": os.path.basename(notebook_path),
        "cells_analyzed": len(cells),
        "code_cells": len([c for c in cells if c["type"] == "code"]),
        "markdown_cells": len([c for c in cells if c["type"] == "markdown"]),
        **result,
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print(f"Оценка: {report.get('score', 'N/A')}/100 ({report.get('grade', 'N/A')})")
    print(f"Отчёт сохранён: {output_path}")


if __name__ == "__main__":
    main()
