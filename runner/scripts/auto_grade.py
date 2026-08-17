#!/usr/bin/env python3
"""
auto_grade.py — CI/CD пайплайн автоматической оценки работ (ISTP).

Запускается GitLab Runner при push в main. Логика:
  0. Точный вход — только если в корне есть `.grade-trigger` (иначе skip).
  1. Выборка deliverables — только файлы `Pr_<N>_*.md` или `Pr_<N>_*.ipynb`
     (N = 1..28). Для MD-only практик (1, 4, 22..28) берутся только `.md`.
     Исключаются: docs/, .git/, .ipynb_checkpoints/, helper-ноутбуки (LLM_Help,
     *help* в имени) и пустые .ipynb (0 символов кода). На каждую практику —
     файл с наибольшим временем последнего коммита (git log, не mtime).
  2. Требования по практике — читаются из docs/Pr_<N>.md (в клоне студента).
  3. Кэш — если sha256 файла совпадает с сохранённым в dashboard, LLM не зовём.
  4. Оценка — grade_md.py / grade_notebook.py (LLM → 0..5).
  5. Персист — POST /api/grade в admin-dashboard (пишет /home/<user>/.grades/).
  6. Отладочный ai_report.json — список всех практик (GitLab artifact).

Env (CI-переменные): STUDENT_ID (default: CI_PROJECT_NAMESPACE = логин/неймспейс форка),
DASHBOARD_API_URL
(default http://admin-dashboard:5000), DASHBOARD_USER, DASHBOARD_PASS,
LLM_CI_BASE_URL/KEY/MODEL.
"""

import os
import sys
import re
import json
import time
import hashlib
import datetime
import subprocess
from pathlib import Path

import requests
from requests.auth import HTTPBasicAuth

from grading_common import GRADER_VERSION

DASHBOARD_BASE = os.environ.get("DASHBOARD_API_URL", "http://admin-dashboard:5000").rstrip("/")
DASHBOARD_USER = os.environ.get("DASHBOARD_USER", "")
DASHBOARD_PASS = os.environ.get("DASHBOARD_PASS", "")
MAX_PRACTICE = 28
MD_ONLY_PRACTICES = {1, 4, 22, 23, 24, 25, 26, 27, 28}
LLM_TIMEOUT_S = int(os.environ.get("LLM_TIMEOUT_S", "300"))
SCRIPTS_DIR = "/runner/scripts"


def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def git(repo_dir, *args):
    """git-команда в repo_dir → stdout (str) или ''."""
    try:
        res = subprocess.run(
            ["git", "-C", repo_dir, *args],
            capture_output=True, text=True, timeout=20,
        )
        return res.stdout.strip() if res.returncode == 0 else ""
    except Exception as exc:
        print(f"  git {list(args)}: {exc}", file=sys.stderr)
        return ""


def git_oneline(repo_dir, n=5):
    out = git(repo_dir, "log", "--oneline", str(n))
    return out.splitlines() if out else []


def _ct(value, fallback):
    try:
        return int(value)
    except (ValueError, TypeError):
        return fallback


def last_touch_ct(repo_dir, rel):
    """Epoch секунд последнего коммита, тронувшего файл rel."""
    out = git(repo_dir, "log", "-1", "--format=%ct", "--", rel)
    return _ct(out.splitlines()[0] if out else "", 0)


def commit_sha_for(repo_dir, rel):
    return git(repo_dir, "log", "-1", "--format=%H", "--", rel)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def notebook_code_chars(path):
    """Символы кода в .ipynb (0 → пустой)."""
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return 0
    total = 0
    for cell in data.get("cells", []):
        if isinstance(cell, dict) and cell.get("cell_type") == "code":
            src = cell.get("source") or []
            if isinstance(src, str):
                src = [src]
            total += sum(len(line) for line in src)
    return total


def find_deliverables(repo_dir):
    """{N: (Path, last_touch_ct)} — лучший кандидат на каждую практику."""
    best = {}
    for p in Path(repo_dir).rglob("*"):
        if not p.is_file():
            continue
        name = p.name
        m = re.match(r"^Pr_(\d+)_", name)
        if not m:
            continue
        n = int(m.group(1))
        if not (1 <= n <= MAX_PRACTICE):
            continue
        if name.endswith(".ipynb") and n in MD_ONLY_PRACTICES:
            continue
        if not (name.endswith(".md") or name.endswith(".ipynb")):
            continue
        parts = set(p.parts)
        if parts & {".git", ".ipynb_checkpoints"} or "docs" in parts:
            continue
        if "help" in name.lower():
            continue
        if name.endswith(".ipynb") and notebook_code_chars(p) == 0:
            continue
        rel = str(p.relative_to(repo_dir))
        ct = last_touch_ct(repo_dir, rel)
        if n not in best or ct > best[n][1]:
            best[n] = (p, ct)
    return best


def dashboard_get_grades(auth, student, practice):
    resp = requests.get(
        f"{DASHBOARD_BASE}/api/grades",
        params={"student": student, "practice": practice},
        auth=auth, timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()
    return data if isinstance(data, list) else []


def dashboard_post_grade(auth, payload):
    resp = requests.post(
        f"{DASHBOARD_BASE}/api/grade",
        json=payload, auth=auth, timeout=30,
    )
    resp.raise_for_status()
    return resp.json() or {}


def grade_file(repo_dir, n, path):
    """Запустить grade_md.py / grade_notebook.py с --requirement docs/Pr_<n>.md."""
    req_path = Path(repo_dir) / "docs" / f"Pr_{n}.md"
    requirement = str(req_path) if req_path.exists() else None

    if path.suffix == ".md":
        cmd = [sys.executable, f"{SCRIPTS_DIR}/grade_md.py", repo_dir, str(n), str(path)]
    else:
        out_path = os.path.join(repo_dir, "ai_report.json")
        cmd = [sys.executable, f"{SCRIPTS_DIR}/grade_notebook.py", str(path), out_path]
    if requirement:
        cmd += ["--requirement", requirement]

    env = os.environ.copy()
    env.setdefault("LLM_CI_BASE_URL", "http://llm:8080/v1")
    env.setdefault("LLM_CI_API_KEY", "local-api-key")
    env.setdefault("LLM_CI_MODEL", "gpt-4o")

    t0 = time.time()
    try:
        res = subprocess.run(
            cmd, cwd=repo_dir, env=env,
            capture_output=True, text=True, timeout=LLM_TIMEOUT_S + 60,
        )
    except subprocess.TimeoutExpired:
        print(f"  ⏱ grader timeout after {LLM_TIMEOUT_S}s", file=sys.stderr)
        return {"score": 0, "feedback": f"grader timeout ({LLM_TIMEOUT_S}s)"}

    dt = round(time.time() - t0, 1)
    if res.stdout.strip():
        print(f"  [{dt}s] {res.stdout.strip()}")
    if res.stderr.strip():
        print(f"  STDERR: {res.stderr.strip()}", file=sys.stderr)

    report_path = os.path.join(repo_dir, "ai_report.json")
    if os.path.exists(report_path):
        try:
            with open(report_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            pass
    return {"score": 0, "feedback": "grader без ai_report.json"}


def resolve_student():
    """Студент = логин = неймспейс форка (testuser/project → testuser).

    Порядок: STUDENT_ID → CI_PROJECT_NAMESPACE → parent(CI_PROJECT_PATH) →
    CI_PROJECT → basename(CI_PROJECT_PATH) → "unknown".
    """
    ns = os.environ.get("CI_PROJECT_NAMESPACE", "").strip()
    path = os.environ.get("CI_PROJECT_PATH", "").strip().rstrip("/")
    candidates = [
        os.environ.get("STUDENT_ID"),
        ns,
        path.rsplit("/", 1)[0] if path else "",
        os.environ.get("CI_PROJECT"),
        os.path.basename(path) if path else "",
    ]
    for cand in candidates:
        if cand and str(cand).strip():
            return str(cand).strip()
    return "unknown"


def write_debug_report(repo_dir, results, commit):
    out = {
        "student": resolve_student(),
        "commit": commit,
        "updated": now_iso(),
        "grader_version": GRADER_VERSION,
        "practices": results,
    }
    path = Path(repo_dir) / "ai_report.json"
    path.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"📄 Debug-отчёт: {path}")


def main():
    repo_dir = os.environ.get("CI_PROJECT_DIR", "")
    if not repo_dir or not os.path.isdir(repo_dir):
        repo_dir = os.getcwd()
    print(f"=== Auto-grade: repo={repo_dir} ===")
    print(f"Дата: {now_iso()}")

    student = resolve_student()
    project_id = os.environ.get("CI_PROJECT_ID", "")

    if not (Path(repo_dir) / ".grade-trigger").exists():
        print("⏭️  .grade-trigger не найден — пропуск оценки.")
        return

    for line in git_oneline(repo_dir, 5):
        print(f"  {line}")

    deliverables = find_deliverables(repo_dir)
    if not deliverables:
        print("⚠️  Deliverables Pr_<N>_*.md/ipynb не найдены.", file=sys.stderr)
        write_debug_report(repo_dir, [], git(repo_dir, "rev-parse", "HEAD"))
        return

    print(f"✅ Практики для оценки: {sorted(deliverables.keys())}")
    auth = HTTPBasicAuth(DASHBOARD_USER, DASHBOARD_PASS) if DASHBOARD_USER else None
    if auth is None:
        print("⚠️  DASHBOARD_USER/DASHBOARD_PASS не заданы — persist отключён (только debug-отчёт).",
              file=sys.stderr)

    commit = git(repo_dir, "rev-parse", "HEAD")
    results = []

    for n in sorted(deliverables):
        path, ct = deliverables[n]
        rel = str(path.relative_to(repo_dir))
        file_sha = sha256_file(path)
        commit_sha = commit_sha_for(repo_dir, rel)
        requirement_path = Path(repo_dir) / "docs" / f"Pr_{n}.md"
        requirement_sha = sha256_file(requirement_path) if requirement_path.exists() else ""
        print(f"\n--- Pr_{n} → {rel}  (file_sha {file_sha[:12]}…) ---")

        cached = None
        if auth is not None:
            try:
                for g in dashboard_get_grades(auth, student, n):
                    if (
                        g.get("file_sha") == file_sha
                        and g.get("requirement_sha") == requirement_sha
                        and g.get("grader_version") == GRADER_VERSION
                    ):
                        cached = g
                        break
            except Exception as exc:
                print(f"  ⚠️ cache-check: {exc}", file=sys.stderr)
            if cached:
                s = cached.get("score", 0)
                print(f"  ⏩ Кэш: файл не изменился → reuse {s}/5 (LLM не зовём)")
                results.append({
                    "practice": n, "file_path": rel, "score": s, "max_score": 5,
                    "feedback": cached.get("feedback", "cached"), "cached": True,
                    "file_sha": file_sha, "commit_sha": commit_sha,
                })
                continue

        report = grade_file(repo_dir, n, path)
        try:
            score = int(report.get("score", 0) or 0)
        except (ValueError, TypeError):
            score = 0
        feedback = report.get("feedback") or report.get("comment") or ""
        print(f"  ✅ Pr_{n}: score={score}/5")

        result_entry = {
            "practice": n, "file_path": rel, "score": score, "max_score": 5,
            "feedback": feedback, "cached": False,
            "file_sha": file_sha, "commit_sha": commit_sha,
        }
        for key in (
            "task_score", "question_score", "control_questions",
            "answered_count", "total_questions", "answered_idx",
            "not_answered_idx",
        ):
            if key in report:
                result_entry[key] = report[key]
        results.append(result_entry)

        if auth is not None:
            payload = {
                "student": student, "practice": n, "score": score, "max_score": 5,
                "feedback": feedback, "comment": feedback, "grade": report.get("grade", ""),
                "file_path": rel, "file_name": path.name, "file_sha": file_sha,
                "commit_sha": commit_sha, "project_id": project_id,
                "requirement_sha": requirement_sha,
                "grader_version": GRADER_VERSION,
                **{
                    key: report[key]
                    for key in (
                        "task_score", "question_score", "control_questions",
                        "answered_count", "total_questions", "answered_idx",
                        "not_answered_idx",
                    )
                    if key in report
                },
            }
            try:
                saved = dashboard_post_grade(auth, payload)
                print(f"  🔗 Persist → {saved.get('saved')} (score={score}/5)")
            except Exception as exc:
                print(f"  ⚠️ dashboard persist FAILED: {exc}", file=sys.stderr)

    write_debug_report(repo_dir, results, commit)
    n_cached = sum(1 for r in results if r.get("cached"))
    print(f"\n=== Итог: {len(results)} практик (cached: {n_cached}, freshly graded: {len(results) - n_cached}) ===")


if __name__ == "__main__":
    main()
