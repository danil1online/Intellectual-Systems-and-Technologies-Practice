#!/usr/bin/env python3
"""
auto_grade.py — CI/CD пайплайн автоматической оценки работ.

Запускается GitLab Runner при push в репозиторий студента.
1. Определяет тип работы по структуре репозитория
2. Запускает appropriate grader
3. Сохраняет ai_report.json
4. Очищает временные файлы

Использование:
    python auto_grade.py
"""

import os
import sys
import json
import datetime
import subprocess
from pathlib import Path


def find_notebooks(repo_dir):
    """Найти .ipynb файлы в репозитории."""
    notebooks = []
    for p in Path(repo_dir).rglob("*.ipynb"):
        if ".ipynb_checkpoints" not in str(p) and "docs" not in str(p):
            notebooks.append(str(p))
    return notebooks


def find_md_reports(repo_dir):
    """Найти md-отчёты в репозитории."""
    reports = []
    for p in Path(repo_dir).rglob("Pr_1_report.md"):
        if "reports" in str(p):
            reports.append(str(p))
    return reports


def get_git_log(repo_dir):
    """Получить историю коммитов."""
    try:
        res = subprocess.run(
            ["git", "log", "--oneline", "-20"],
            cwd=repo_dir, capture_output=True, text=True, timeout=10
        )
        if res.returncode == 0:
            return res.stdout.strip().split("\n")
    except Exception:
        pass
    return []


def grade_practice_notebook(repo_dir, notebook_path):
    """Оценить notebook-практику (Pr_2 — Pr_21)."""
    print(f"  Оцениваю notebook: {notebook_path}")
    
    cmd = [
        sys.executable,
        "/runner/scripts/grade_notebook.py",
        notebook_path,
        "ai_report.json",
    ]
    
    env = os.environ.copy()
    env["LLM_CI_BASE_URL"] = os.environ.get("LLM_CI_BASE_URL", "http://llm:8080/v1")
    env["LLM_CI_API_KEY"] = os.environ.get("LLM_CI_API_KEY", "local-api-key")
    env["LLM_CI_MODEL"] = os.environ.get("LLM_CI_MODEL", "gpt-4o")
    
    result = subprocess.run(cmd, cwd=repo_dir, env=env, capture_output=True, text=True, timeout=300)
    print(f"  {result.stdout.strip()}")
    if result.stderr:
        print(f"  STDERR: {result.stderr.strip()}")
    
    # Проверяем ai_report.json
    report_path = os.path.join(repo_dir, "ai_report.json")
    if os.path.exists(report_path):
        with open(report_path, "r") as f:
            report = json.load(f)
        print(f"  Результат: score={report.get('score', 'N/A')}/5")
        return report
    
    return {"score": 0, "feedback": "Не удалось создать отчёт", "issues": ["Ошибка оценки"]}


def grade_practice_md(repo_dir, md_path=None):
    """Оценить md-отчёт (Pr_1)."""
    if not md_path:
        # Ищем Pr_*.md
        reports = find_md_reports(repo_dir)
        if reports:
            md_path = reports[0]
        else:
            return {"score": 0, "feedback": "Отчёт .md не найден", "issues": ["Нет отчёта"]}
    
    print(f"  Оцениваю md-отчёт: {md_path}")
    
    # Определяем номер практики из имени файла
    filename = os.path.basename(md_path)
    practice_num = 1
    for i in range(1, 21):
        if f"Pr_{i}_" in filename:
            practice_num = i
            break
    
    cmd = [
        sys.executable,
        "/runner/scripts/grade_md.py",
        repo_dir,
        str(practice_num),
        md_path,
    ]
    
    env = os.environ.copy()
    env["LLM_CI_BASE_URL"] = os.environ.get("LLM_CI_BASE_URL", "http://llm:8080/v1")
    env["LLM_CI_API_KEY"] = os.environ.get("LLM_CI_API_KEY", "local-api-key")
    env["LLM_CI_MODEL"] = os.environ.get("LLM_CI_MODEL", "gpt-4o")
    
    result = subprocess.run(cmd, cwd=repo_dir, env=env, capture_output=True, text=True, timeout=300)
    print(f"  {result.stdout.strip()}")
    if result.stderr:
        print(f"  STDERR: {result.stderr.strip()}")
    
    report_path = os.path.join(repo_dir, "ai_report.json")
    if os.path.exists(report_path):
        with open(report_path, "r") as f:
            report = json.load(f)
        print(f"  Результат: score={report.get('score', 'N/A')}/5")
        return report
    
    return {"score": 0, "feedback": "Не удалось создать отчёт", "issues": ["Ошибка оценки"]}


def main():
    repo_dir = os.environ.get("CI_PROJECT_DIR", "/runner/work/istp")
    
    if not os.path.exists(repo_dir):
        print(f"❌ Репозиторий не найден: {repo_dir}")
        sys.exit(1)
    
    trigger_path = os.path.join(repo_dir, ".grade-trigger")
    if not os.path.exists(trigger_path):
        print("⏭️  Триггер оценки не найден (.grade-trigger). Пропуск оценки.")
        sys.exit(0)
    
    print(f"=== Auto-grade для: {repo_dir} ===")
    print(f"Дата: {datetime.datetime.now().isoformat()}")
    print(f"Commits: {get_git_log(repo_dir)[:5]}")
    
    # Ищем notebook-практики (Pr_2 — Pr_21)
    notebooks = find_notebooks(repo_dir)
    
    # Ищем md-отчёты (Pr_1)
    md_reports = find_md_reports(repo_dir)
    
    if notebooks:
        print(f"\nНайдено {len(notebooks)} notebook-файлов")
        # Оцениваем последний/первый notebook
        for nb in notebooks:
            report = grade_practice_notebook(repo_dir, nb)
            break  # Оцениваем первый найденный
    elif md_reports:
        print(f"\nНайдено {len(md_reports)} md-отчётов")
        for md in md_reports:
            report = grade_practice_md(repo_dir, md)
            break  # Оцениваем первый найденный
    else:
        report = {
            "score": 0,
            "feedback": "Работа не найдена (нет .ipynb или Pr_*.md)",
            "issues": ["Нет файлов для оценки"],
            "recommendations": ["Создайте отчёт в папке reports/"],
        }
    
    # Сохраняем финальный отчёт
    output_path = os.path.join(repo_dir, "ai_report.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    
    print(f"\n=== Итог: score={report.get('score', 'N/A')}/5 ===")
    print(f"Отчёт: {output_path}")


if __name__ == "__main__":
    main()
