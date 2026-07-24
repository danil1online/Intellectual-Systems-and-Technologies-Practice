"""
Роуты Admin Dashboard — API для чтения и анализа grading_log.json.
"""

import os
import json
import datetime
from flask import Blueprint, jsonify, request, render_template

api_bp = Blueprint("api", __name__)

LOG_FILE = os.environ.get("LOG_FILE", "/app/logs/grading_log.json")


def read_logs():
    """Читать все записи из лог-файла."""
    logs = []
    if not os.path.exists(LOG_FILE):
        return logs

    try:
        with open(LOG_FILE, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        logs.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
    except FileNotFoundError:
        pass

    return logs


@api_bp.route("/")
def index():
    """Главная страница — дашборд."""
    return render_template("dashboard.html", title="Панель преподавателя")


@api_bp.route("/api/logs")
def get_logs():
    """Получить логи с фильтрацией."""
    logs = read_logs()

    # Фильтрация по студенту
    student = request.args.get("student")
    if student:
        logs = [l for l in logs if l.get("student") == student]

    # Фильтрация по дате
    date_from = request.args.get("date_from")
    date_to = request.args.get("date_to")
    if date_from:
        logs = [l for l in logs if l.get("timestamp", "") >= date_from]
    if date_to:
        logs = [l for l in logs if l.get("timestamp", "") <= date_to]

    # Фильтрация по категории
    category = request.args.get("category")
    if category:
        logs = [l for l in logs if l.get("category") == category]

    # Сортировка по timestamp (новые первые)
    logs = sorted(logs, key=lambda x: x.get("timestamp", ""), reverse=True)

    return jsonify(logs)


@api_bp.route("/api/stats")
def get_stats():
    """Статистика: LAZY/SMART ratio по студентам."""
    logs = read_logs()

    # Группировка по студенту
    stats = {}
    for log in logs:
        student = log.get("student", "unknown")
        if student not in stats:
            stats[student] = {"total": 0, "lazy": 0, "smart": 0, "penalty": 0}

        stats[student]["total"] += 1
        category = log.get("category", "UNKNOWN")
        if category == "LAZY":
            stats[student]["lazy"] += 1
        elif category == "SMART":
            stats[student]["smart"] += 1

        if log.get("penalty", False):
            stats[student]["penalty"] += 1

    # Вычисляем LAZY%
    for student in stats:
        total = stats[student]["total"]
        if total > 0:
            stats[student]["lazy_pct"] = round(stats[student]["lazy"] / total * 100, 1)
            stats[student]["smart_pct"] = round(stats[student]["smart"] / total * 100, 1)

    return jsonify(stats)


@api_bp.route("/api/export")
def export_logs():
    """Экспорт логов в CSV."""
    logs = read_logs()

    # Применяем те же фильтры
    student = request.args.get("student")
    if student:
        logs = [l for l in logs if l.get("student") == student]

    date_from = request.args.get("date_from")
    date_to = request.args.get("date_to")
    if date_from:
        logs = [l for l in logs if l.get("timestamp", "") >= date_from]
    if date_to:
        logs = [l for l in logs if l.get("timestamp", "") <= date_to]

    # CSV формат
    lines = ["timestamp,student,category,penalty,reason,prompt"]
    for log in logs:
        ts = log.get("timestamp", "")
        st = log.get("student", "")
        cat = log.get("category", "")
        pen = log.get("penalty", False)
        reason = log.get("reason", "").replace(",", ";").replace('"', "'")
        prompt = log.get("prompt", "").replace(",", ";").replace("\n", " ").replace('"', "'")[:500]

        lines.append(f'"{ts}","{st}","{cat}","{pen}","{reason}","{prompt}"')

    csv_content = "\n".join(lines)
    return csv_content, 200, {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": f'attachment; filename="grading_logs_{datetime.date.today()}.csv"'
    }


@api_bp.route("/api/summary")
def get_summary():
    """Общая сводка за период."""
    logs = read_logs()

    total = len(logs)
    lazy = sum(1 for l in logs if l.get("category") == "LAZY")
    smart = sum(1 for l in logs if l.get("category") == "SMART")
    penalties = sum(1 for l in logs if l.get("penalty", False))

    unique_students = len(set(l.get("student") for l in logs))

    # Динамика по дням
    daily = {}
    for log in logs:
        ts = log.get("timestamp", "")[:10]  # YYYY-MM-DD
        if ts not in daily:
            daily[ts] = {"lazy": 0, "smart": 0}
        if log.get("category") == "LAZY":
            daily[ts]["lazy"] += 1
        else:
            daily[ts]["smart"] += 1

    return jsonify({
        "total_requests": total,
        "lazy": lazy,
        "smart": smart,
        "penalties": penalties,
        "unique_students": unique_students,
        "daily": daily,
    })
