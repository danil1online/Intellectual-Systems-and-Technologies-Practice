"""
Роуты Admin Dashboard — API для чтения и анализа grading_log.json.
"""

import os
import json
import csv
import datetime
import io
import base64
import urllib.parse
import requests
from flask import Blueprint, jsonify, request, render_template, Response, abort, redirect

api_bp = Blueprint("api", __name__)

DASHBOARD_USERNAME = os.environ.get("DASHBOARD_USERNAME", "admin")
DASHBOARD_PASSWORD = os.environ.get("DASHBOARD_PASSWORD", "")

def require_auth():
    """Проверка базовой аутентификации."""
    if not DASHBOARD_PASSWORD:
        return True
    auth = request.headers.get("Authorization")
    if not auth:
        return False
    try:
        auth_type, auth_data = auth.split(" ", 1)
        if auth_type != "Basic":
            return False
        username, password = base64.b64decode(auth_data).decode("utf-8").split(":", 1)
        return username == DASHBOARD_USERNAME and password == DASHBOARD_PASSWORD
    except Exception:
        return False

def auth_required(f):
    """Декоратор для проверки аутентификации."""
    from functools import wraps
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not require_auth():
            return Response(
                'Authentication required',
                401,
                {'WWW-Authenticate': 'Basic realm="Dashboard"'}
            )
        return f(*args, **kwargs)
    return decorated_function

GITLAB_URL = os.environ.get("GITLAB_URL", "http://localhost")
GITLAB_TOKEN = os.environ.get("GITLAB_ADMIN_TOKEN", "")


def gitlab_api_request(endpoint):
    """Запрос к GitLab API."""
    if not GITLAB_TOKEN:
        return []
    headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
    try:
        resp = requests.get(f"{GITLAB_URL}/api/v4/{endpoint}", headers=headers, timeout=10)
        return resp.json() if resp.status_code == 200 else []
    except Exception:
        return []

_STUDENT_CACHE = {}
_NO_NAME = "—"
_WINDOW_MIN = 120  # окно «вопрос → выгрузка отчёта», минут


def _parse_ts(value):
    """ISO/'YYYY-MM-DD HH:MM:SS' → datetime (naive/aware) или None."""
    if not value or not isinstance(value, str):
        return None
    s = value.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        return datetime.datetime.fromisoformat(s)
    except ValueError:
        pass
    for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S",
                "%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S"):
        try:
            return datetime.datetime.strptime(s, fmt)
        except ValueError:
            continue
    return None


def _to_naive_local(dt):
    """aware → local → naive; naive → как есть (для честного сравнения окон)."""
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone().replace(tzinfo=None)
    return dt


def _fmt_ts(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S") if dt else "—"


def student_identity(username):
    """Имя/фамилия из GitLab (users?username=) + логины. Кэш по логину (case-insens)."""
    key = (username or "").strip().lower()
    if not key or key in ("unknown", "none", "local_user"):
        return {"first_name": _NO_NAME, "last_name": _NO_NAME,
                "gitlab_username": username or _NO_NAME,
                "jupyter_username": username or _NO_NAME,
                "display": _NO_NAME}
    if key in _STUDENT_CACHE:
        return _STUDENT_CACHE[key]
    first, last = _NO_NAME, _NO_NAME
    if GITLAB_TOKEN:
        try:
            users = gitlab_api_request("users?" + urllib.parse.urlencode({"username": username}))
            if isinstance(users, list) and users and users[0]:
                name = (users[0].get("name") or "").strip()
                parts = name.split(None, 1)
                if parts:
                    first = parts[0]
                if len(parts) > 1:
                    last = parts[1]
        except Exception:
            pass
    ident = {
        "first_name": first,
        "last_name": last,
        "gitlab_username": username,
        "jupyter_username": username,
        "display": ((first + " " + last).strip() or _NO_NAME),
    }
    _STUDENT_CACHE[key] = ident
    return ident


def _q_category(entry):
    cat = (entry.get("category") or "").lower()
    if cat in ("lazy", "smart"):
        return cat
    if entry.get("is_lazy"):
        return "lazy"
    return "other"


def _q_prompt(entry):
    p = entry.get("prompt") or entry.get("question") or entry.get("text") or ""
    p = str(p).strip()
    if len(p) > 120:
        p = p[:119] + "…"
    return p or "(пустой вопрос)"


def _log_question(entry):
    return {
        "timestamp": entry.get("timestamp", "—"),
        "prompt": _q_prompt(entry),
        "category": entry.get("category") or ("lazy" if entry.get("is_lazy") else "other"),
        "penalty": entry.get("penalty", 0),
    }


def _attribute_logs(student_logs, reports):
    """reports: [{"dt": naive|None, ...}]. Каждый log → ближайшему ПОСЛЕДУЮЩЕМУ отчёту
    в пределах _WINDOW_MIN минут (дедуп: вопрос считается один раз).
    Возвращает (by_report[i], unattributed)."""
    by_report = [[] for _ in reports]
    unattributed = []
    order = sorted(range(len(reports)), key=lambda i: reports[i]["dt"] or datetime.datetime.min)
    for e in student_logs:
        ldt = _to_naive_local(_parse_ts(e.get("timestamp")))
        if ldt is None:
            unattributed.append(e)
            continue
        chosen = None
        for i in order:
            rdt = reports[i]["dt"]
            if rdt is None or rdt < ldt:
                continue
            if (rdt - ldt) > datetime.timedelta(minutes=_WINDOW_MIN):
                break
            chosen = i
            break
        if chosen is None:
            unattributed.append(e)
        else:
            by_report[chosen].append(e)
    return by_report, unattributed


def _make_row(u, practice, score, max_score, feedback, rdt, lazy, smart,
              is_orphan, has_jupyter_logs):
    ident = student_identity(u)
    if is_orphan:
        gitlab_user, jupyter_user = _NO_NAME, u
    else:
        gitlab_user = u
        jupyter_user = u if has_jupyter_logs else _NO_NAME
    lazy_q = [_log_question(e) for e in lazy]
    smart_q = [_log_question(e) for e in smart]
    return {
        "student": u,
        "first_name": ident["first_name"],
        "last_name": ident["last_name"],
        "gitlab_username": gitlab_user,
        "jupyter_username": jupyter_user,
        "display": ident["display"],
        "practice": practice,
        "score": None if score is None else score,
        "max_score": max_score,
        "feedback": feedback or "—",
        "lazy_count": len(lazy_q),
        "lazy_questions": lazy_q,
        "smart_count": len(smart_q),
        "smart_questions": smart_q,
        "report_dt": rdt,
        "report_time": _fmt_ts(rdt),
        "orphan": is_orphan,
    }


def _row_matches(r, student, practice, date_from, date_to, time_from, time_to):
    if student and r["student"] != student:
        return False
    if practice not in (None, ""):
        try:
            p = int(practice)
        except (TypeError, ValueError):
            p = practice
        if r["practice"] is None or str(r["practice"]) != str(p):
            return False
    rdt = r["report_dt"]
    want_dt = bool(date_from or date_to or (time_from and time_to))
    if want_dt and rdt is None:
        return False
    if date_from:
        try:
            if rdt.date() < datetime.datetime.strptime(date_from, "%Y-%m-%d").date():
                return False
        except ValueError:
            pass
    if date_to:
        try:
            if rdt.date() > datetime.datetime.strptime(date_to, "%Y-%m-%d").date():
                return False
        except ValueError:
            pass
    if time_from and time_to and date_from and date_to and date_from == date_to:
        try:
            tf = datetime.datetime.strptime(time_from, "%H:%M").time()
            tt = datetime.datetime.strptime(time_to, "%H:%M").time()
            if not (tf <= rdt.time() <= tt):
                return False
        except ValueError:
            pass
    return True


def build_results(student=None, practice=None, date_from=None, date_to=None,
                  time_from=None, time_to=None):
    """Единая таблица: строки (student × практика-отчёт) + orphan-строки ментора.
    Lazy/Smart — вопросы из ментор-логов того же логина, приписанные к ближайшему
    последующему отчёту (≤ _WINDOW_MIN минут)."""
    grades = read_grades()
    logs = read_logs()

    logs_by_student = {}
    for l in logs:
        if l.get("student"):
            logs_by_student.setdefault(l["student"], []).append(l)

    reports_by_student = {}
    for g in grades:
        if g.get("student"):
            reports_by_student.setdefault(g["student"], []).append(g)

    rows = []
    for u in set(reports_by_student) | set(logs_by_student):
        reps = reports_by_student.get(u, [])
        stlogs = logs_by_student.get(u, [])
        has_logs = bool(stlogs)

        rinfo = [{"dt": _to_naive_local(_parse_ts(g.get("timestamp"))), "rec": g} for g in reps]
        by_report, _unattrib = _attribute_logs(stlogs, rinfo)

        for ri, rep in enumerate(rinfo):
            rec = rep["rec"]
            bucket = by_report[ri]
            lazy = [e for e in bucket if _q_category(e) == "lazy"]
            smart = [e for e in bucket if _q_category(e) == "smart"]
            rows.append(_make_row(
                u, rec.get("practice"), rec.get("score"), rec.get("max_score", 5),
                rec.get("reason") or rec.get("feedback") or "—", rep["dt"],
                lazy, smart, is_orphan=False, has_jupyter_logs=has_logs,
            ))

        if not reps and stlogs:
            ts_list = [t for t in (_to_naive_local(_parse_ts(e.get("timestamp"))) for e in stlogs) if t]
            last = max(ts_list) if ts_list else None
            orphan_lazy = [e for e in stlogs if _q_category(e) == "lazy"]
            orphan_smart = [e for e in stlogs if _q_category(e) == "smart"]
            rows.append(_make_row(
                u, None, None, 5, "—", last, orphan_lazy, orphan_smart,
                is_orphan=True, has_jupyter_logs=True,
            ))

    rows = [r for r in rows
            if _row_matches(r, student, practice, date_from, date_to, time_from, time_to)]
    rows.sort(key=lambda r: (r["student"],
                             r["practice"] if r["practice"] is not None else 9999,
                             r["orphan"],
                             r["report_dt"] or datetime.datetime.min))
    return rows


def read_logs():
    """Читать все записи из логов всех пользователей."""
    import glob
    logs = []
    log_files = glob.glob("/home/*/.logs/grading_log.json")
    for log_file in sorted(log_files):
        if not os.path.exists(log_file):
            continue
        try:
            with open(log_file, "r", encoding="utf-8") as f:
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


def read_grades():
    """Читать все оценки из /home/*/.grades/pr_*.json (per-practice upsert от CI)."""
    import glob
    import re
    grades = []
    grade_files = glob.glob("/home/*/.grades/pr_*.json")
    for gf in sorted(grade_files):
        try:
            with open(gf, "r", encoding="utf-8") as f:
                record = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            continue
        parts = gf.split("/")
        student = "unknown"
        for i, p in enumerate(parts):
            if p == "home" and i + 1 < len(parts):
                student = parts[i + 1]
                break
        m = re.match(r"pr_(\d+)\.json$", gf.rsplit("/", 1)[-1])
        practice = int(m.group(1)) if m else record.get("practice", 0)
        record["student"] = student
        record["practice"] = practice
        record["source_file"] = gf
        grades.append(record)

    return grades


@api_bp.route("/health")
def health():
    """Health check — без аутентификации."""
    return jsonify({"status": "ok"})


@api_bp.route("/")
@auth_required
def index():
    """Главная страница — дашборд."""
    return render_template("dashboard.html", title="Панель преподавателя")


@api_bp.route("/logout")
def logout():
    """Logout from dashboard (clears Basic Auth session)."""
    response = Response('Logged out', status=200)
    response.headers['WWW-Authenticate'] = 'Basic realm="Dashboard"'
    return response


@api_bp.route("/api/logs")
@auth_required
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
@auth_required
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
@auth_required
def export_results():
    """CSV: единая таблица (студент, практика, оценка, feedback, lazy/smart, время отчёта)."""
    rows = build_results(
        student=request.args.get("student", "").strip() or None,
        practice=request.args.get("practice", "").strip() or None,
        date_from=request.args.get("date_from", "").strip() or None,
        date_to=request.args.get("date_to", "").strip() or None,
        time_from=request.args.get("time_from", "").strip() or None,
        time_to=request.args.get("time_to", "").strip() or None,
    )

    out = io.StringIO()
    w = csv.writer(out, lineterminator="\n", delimiter=";")
    w.writerow(["Студент", "gitlab", "jupyter", "Практика", "Оценка", "Feedback",
                "#Lazy", "Lazy-Вопросы", "#Smart", "Smart-Вопросы", "Время отчёта"])

    def jlist(qs):
        return " | ".join(f"[{q['timestamp']}] {q['prompt']}".replace("\n", " ") for q in qs)

    for r in rows:
        name = (r["first_name"] + " " + r["last_name"]).strip() or r["student"]
        w.writerow([
            name,
            r["gitlab_username"],
            r["jupyter_username"],
            r["practice"] if r["practice"] is not None else "—",
            r["score"] if r["score"] is not None else "—",
            str(r["feedback"]).replace("\n", " "),
            r["lazy_count"],
            jlist(r["lazy_questions"]),
            r["smart_count"],
            jlist(r["smart_questions"]),
            r["report_time"],
        ])

    csv_bytes = "﻿".encode("utf-8") + out.getvalue().encode("utf-8")
    return Response(csv_bytes, 200, {
        "Content-Type": "text/csv; charset=utf-8; delimiter=;",
        "Content-Disposition": f'attachment; filename="istp_results_{datetime.date.today()}.csv"',
    })


@api_bp.route("/api/summary")
@auth_required
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


@api_bp.route("/api/grades")
@auth_required
def get_grades():
    """Получить оценки студентов."""
    grades = read_grades()

    # Фильтрация по студенту
    student = request.args.get("student")
    if student:
        grades = [g for g in grades if g.get("student") == student]

    # Фильтрация по практике
    practice = request.args.get("practice")
    if practice:
        grades = [g for g in grades if str(g.get("practice", "")) == str(practice)]

    # Фильтрация по дате
    date_from = request.args.get("date_from")
    date_to = request.args.get("date_to")
    if date_from:
        grades = [g for g in grades if g.get("timestamp", "") >= date_from]
    if date_to:
        grades = [g for g in grades if g.get("timestamp", "") <= date_to]

    # Сортировка по timestamp (новые первые)
    grades = sorted(grades, key=lambda x: x.get("timestamp", ""), reverse=True)

    return jsonify(grades)


@api_bp.route("/api/grade", methods=["POST"])
@auth_required
def post_grade():
    """Runner отправляет оценку → upsert в /home/<student>/.grades/pr_<N>.json."""
    data = request.get_json(silent=True) or {}
    student = data.get("student")
    if not student or student == "unknown":
        return jsonify({"error": "field 'student' is required"}), 400

    try:
        practice = int(data.get("practice", 0))
    except (TypeError, ValueError):
        practice = 0

    grades_dir = os.path.join("/home", str(student), ".grades")
    os.makedirs(grades_dir, exist_ok=True)
    report_path = os.path.join(grades_dir, f"pr_{practice}.json")

    existing = {}
    if os.path.exists(report_path):
        try:
            with open(report_path, "r", encoding="utf-8") as f:
                existing = json.load(f)
        except (json.JSONDecodeError, OSError):
            existing = {}

    now = datetime.datetime.now().isoformat()
    record = {**existing, **data, "student": student, "practice": practice,
              "timestamp": now, "graded_at": now}
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(record, f, ensure_ascii=False, indent=2)

    return jsonify({"status": "ok", "saved": report_path, "student": student,
                    "practice": practice, "score": data.get("score")})


@api_bp.route("/api/gitlab/groups")
@auth_required
def get_gitlab_groups():
    """Получить список групп GitLab."""
    return jsonify(gitlab_api_request("groups?per_page=100"))


@api_bp.route("/api/gitlab/projects")
@auth_required
def get_gitlab_projects():
    """Получить список проектов GitLab."""
    return jsonify(gitlab_api_request("projects?per_page=100"))


@api_bp.route("/api/gitlab/stats")
@auth_required
def get_gitlab_stats():
    """Сводка по GitLab."""
    groups = gitlab_api_request("groups?per_page=100")
    projects = gitlab_api_request("projects?per_page=100")
    users = gitlab_api_request("users?per_page=100")
    return jsonify({
        "total_groups": len(groups),
        "total_projects": len(projects),
        "total_users": len(users),
    })


@api_bp.route("/api/results")
@auth_required
def get_results():
    """Единая таблица: результаты по (студент × практика) + lazy/smart из ментор-логов.

    Фильтры: student, practice, date_from, date_to (+ time_from/time_to на один день).
    Логин «сломался» (jupyter != gitlab) → отдельная orphan-строка, без ошибки.
    """
    rows = build_results(
        student=request.args.get("student", "").strip() or None,
        practice=request.args.get("practice", "").strip() or None,
        date_from=request.args.get("date_from", "").strip() or None,
        date_to=request.args.get("date_to", "").strip() or None,
        time_from=request.args.get("time_from", "").strip() or None,
        time_to=request.args.get("time_to", "").strip() or None,
    )
    return jsonify(rows)


@api_bp.route("/api/students")
@auth_required
def get_students_list():
    """Список студентов (union: gitlab-отчёты + ментор-логи) с first/last из GitLab."""
    students = sorted(set(g.get("student") for g in read_grades()) |
                      set(l.get("student") for l in read_logs()))
    students = [s for s in students if s]
    out = []
    for u in students:
        ident = student_identity(u)
        out.append({"student": u, "first_name": ident["first_name"],
                    "last_name": ident["last_name"], "display": ident["display"]})
    return jsonify(out)


def create_api_blueprint():
    """Создание и возврат API blueprint."""
    return api_bp
