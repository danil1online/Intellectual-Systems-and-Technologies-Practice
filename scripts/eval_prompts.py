#!/usr/bin/env python3
"""A/B-стенд вариантов промптов LLM-оценки (офлайн, против живого LLM-сервера).

Варианты:
  V0 — текущий production-промпт (полный эталон + отчёт + чек-лист)
  V1 — обрезанный эталон (заголовки + код-блоки + раздел контрольных вопросов)
  V2 — без эталона (инструкции + чек-лист + отчёт)
  V3 — V1 + умная обрезка отчёта (при превышении лимита сохраняется хвост
       с заголовком «Контрольные вопросы», режется середина)

Общие параметры: temperature=0, max_tokens=512.
Метрики: latency; strict-JSON; task-булевы LLM vs regex-маркеры детерминистического
слоя («LLM true + regex false» = галлюцинация, «LLM false + regex true» = недооценка).

Запуск с сервера стека:
  GITLAB_ADMIN_TOKEN=... \
  LLM_BASE_URL=http://192.168.2.83:8080/v1 LLM_API_KEY=api-key \
  LLM_MODEL=GigaChat3.1-10B-A1.8B-q4_K_M.gguf \
  python3 scripts/eval_prompts.py [--students student_ita_01 ...] [--practices 1 22 23]

Результаты: JSONL в --out (по умолчанию /tmp/opencode/eval_results.jsonl),
итоговая сводка — в stdout и --summary.
"""
import argparse
import json
import os
import re
import statistics
import sys
import time
from pathlib import Path

SCRIPTS_DIR = str(Path(__file__).resolve().parent.parent / "runner" / "scripts")
sys.path.insert(0, SCRIPTS_DIR)

os.environ.setdefault("LLM_TIMEOUT_S", "900")

from grading_common import (  # noqa: E402
    SPEC_SYSTEM_PROMPT,
    build_spec_prompt,
    load_ideal_report,
    parse_llm_json,
    validate_spec_payload,
    chat_completion,
    _task_llm_flag,
    _task_regex_ok,
    _work_section,
)
from practice_specs import PRACTICE_SPECS  # noqa: E402

import requests  # noqa: E402

GITLAB_URL = os.environ.get("GITLAB_URL", "http://localhost")
TOKEN = os.environ.get("GITLAB_ADMIN_TOKEN", "")
LLM_BASE_URL = os.environ.get("LLM_BASE_URL", "http://192.168.2.83:8080/v1").rstrip("/")
LLM_API_KEY = os.environ.get("LLM_API_KEY", "api-key")
LLM_MODEL = os.environ.get("LLM_MODEL", "GigaChat3.1-10B-A1.8B-q4_K_M.gguf")

DEFAULT_STUDENTS = ["student_ita_01", "student_ita_03", "student_ita_05", "student_ita_06"]
DEFAULT_PRACTICES = [1, 22, 23]


def trim_ideal_report(ideal_text):
    """V1: из эталона оставить заголовки, код-блоки и раздел контрольных вопросов.

    Проза между блоками выбрасывается — для сравнения студенту нужны команды/выводы
    по шагам (заголовок шага несёт описание) и образцы ответов на вопросы.
    """
    lines = ideal_text.splitlines()
    out = []
    in_code = False
    in_questions = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code = not in_code
            out.append(line)
            continue
        if in_code:
            out.append(line)
            continue
        is_heading = stripped.startswith("#")
        if is_heading and re.search(r"контрольн[ыы]е?\s+вопрос|ответы на контрольные", stripped, re.I):
            in_questions = True
        if in_questions or is_heading:
            out.append(line)
    text = "\n".join(out).strip()
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text


def truncate_report_smart(report, max_chars):
    """V3: при превышении лимита сохранить начало и хвост с «Контрольные вопросы»."""
    if len(report) <= max_chars:
        return report
    m = re.search(
        r"^\s*#{1,6}[ \t]+.*контрольн[ыы]е?\s+вопрос.*$", report,
        flags=re.MULTILINE | re.IGNORECASE,
    )
    if m and m.start() > 0:
        tail = report[m.start():]
        head_budget = max_chars - len(tail) - 60
        if head_budget > 1500:
            return report[:head_budget] + "\n…[середина отчёта обрезана]…\n" + tail
    return report[:max_chars] + "\n…[отчёт обрезан]"


def build_variants(spec, practice_num, report, ideal):
    """{variant: prompt}."""
    trimmed = trim_ideal_report(ideal) if ideal else None
    prompts = {
        "V0": build_spec_prompt(spec, practice_num, report, ideal_report=ideal),
        "V1": build_spec_prompt(spec, practice_num, report, ideal_report=trimmed),
        "V2": build_spec_prompt(spec, practice_num, report, ideal_report=None),
    }
    smart = truncate_report_smart(report, 24000)
    prompts["V3"] = (
        build_spec_prompt(spec, practice_num, smart, ideal_report=trimmed)
        if smart != report else prompts["V1"]
    )
    return prompts


def fetch_report(project_id, practice):
    path = f"reports/Pr_{practice}/Pr_{practice}_report.md"
    resp = requests.get(
        f"{GITLAB_URL}/api/v4/projects/{project_id}/repository/files/{path.replace('/', '%2F')}/raw",
        params={"ref": "main"}, headers={"PRIVATE-TOKEN": TOKEN}, timeout=30,
    )
    if resp.status_code != 200:
        return None
    return resp.text


def grade_call(prompt):
    t0 = time.time()
    content = chat_completion(
        prompt, SPEC_SYSTEM_PROMPT, LLM_BASE_URL, LLM_API_KEY, LLM_MODEL,
        temperature=0.0, max_tokens=512,
    )
    dt = round(time.time() - t0, 1)
    parsed, mode = parse_llm_json(content)
    return content, dt, parsed, mode


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--students", nargs="*", default=DEFAULT_STUDENTS)
    ap.add_argument("--practices", nargs="*", type=int, default=DEFAULT_PRACTICES)
    ap.add_argument("--variants", nargs="*", default=["V0", "V1", "V2", "V3"])
    ap.add_argument("--cooldown", type=int, default=120,
                    help="пауза между блоками вариантов, с (сброс KV-кэша llama.cpp)")
    ap.add_argument("--out", default="/tmp/opencode/eval_results.jsonl")
    ap.add_argument("--summary", default="/tmp/opencode/eval_summary.txt")
    args = ap.parse_args()

    projects = {
        p["path_with_namespace"].split("/")[0]: p["id"]
        for p in requests.get(
            f"{GITLAB_URL}/api/v4/projects", params={"per_page": 100},
            headers={"PRIVATE-TOKEN": TOKEN}, timeout=30,
        ).json()
    }

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    done_keys = set()
    if out_path.exists():
        for line in out_path.read_text(encoding="utf-8").splitlines():
            try:
                rec = json.loads(line)
                done_keys.add((rec["student"], rec["practice"], rec["variant"]))
            except (json.JSONDecodeError, KeyError):
                pass

    total_calls = 0
    with out_path.open("a", encoding="utf-8") as out:
        for vi, variant in enumerate(args.variants):
            if vi > 0 and args.cooldown > 0:
                print(f"== COOLDOWN {args.cooldown}s перед {variant} (сброс KV-кэша) ==", flush=True)
                time.sleep(args.cooldown)
            for student in args.students:
                project_id = projects.get(student)
                if not project_id:
                    print(f"!! проект {student} не найден — пропускаю", flush=True)
                    continue
                for n in args.practices:
                    key = (student, n, variant)
                    if key in done_keys:
                        continue
                    spec = PRACTICE_SPECS[n]
                    report = fetch_report(project_id, n)
                    if not report:
                        print(f"== {student} Pr_{n}: отчёт не найден — пропускаю", flush=True)
                        continue
                    ideal = load_ideal_report(n)
                    work_text = _work_section(report)
                    prompts = build_variants(spec, n, report, ideal)
                    total_calls += 1
                    print(f"-> {variant} {student} Pr_{n} (prompt={len(prompts[variant])} chars)...", flush=True)
                    try:
                        content, dt, parsed, mode = grade_call(prompts[variant])
                    except Exception as exc:
                        rec = {
                            "student": student, "practice": n, "variant": variant,
                            "error": str(exc), "latency_s": None,
                        }
                        out.write(json.dumps(rec, ensure_ascii=False) + "\n")
                        out.flush()
                        print(f"   ERROR: {exc}", flush=True)
                        continue

                    errors = validate_spec_payload(parsed, spec) if parsed else ["no-json"]
                    llm_tasks = [
                        _task_llm_flag(item)
                        for item in (parsed.get("tasks") if isinstance(parsed.get("tasks"), list) else [])
                    ]
                    regex_tasks = [
                        _task_regex_ok(task, work_text) for task in spec["tasks"]
                    ]
                    llm_q = [
                        _task_llm_flag(item)
                        for item in (parsed.get("questions") if isinstance(parsed.get("questions"), list) else [])
                    ]
                    rec = {
                        "student": student, "practice": n, "variant": variant,
                        "prompt_chars": len(prompts[variant]),
                        "latency_s": dt,
                        "parse_mode": mode,
                        "strict": mode == "strict",
                        "validation_errors": errors,
                        "tasks_llm": llm_tasks,
                        "tasks_regex": regex_tasks,
                        "hallucinated": [i + 1 for i in range(len(spec["tasks"]))
                                         if i < len(llm_tasks) and llm_tasks[i] and not regex_tasks[i]],
                        "undercounted": [i + 1 for i in range(len(spec["tasks"]))
                                         if i < len(llm_tasks) and not llm_tasks[i] and regex_tasks[i]],
                        "questions_llm": llm_q,
                        "raw_preview": content[:300],
                    }
                    out.write(json.dumps(rec, ensure_ascii=False) + "\n")
                    out.flush()
                    print(
                        f"   {dt}s mode={mode} tasks_llm={sum(llm_tasks)}/{len(spec['tasks'])} "
                        f"regex={sum(regex_tasks)}/{len(spec['tasks'])} "
                        f"halluc={rec['hallucinated']} under={rec['undercounted']}",
                        flush=True,
                    )

    print(f"\nВыполнено вызовов: {total_calls}. Сводка:", flush=True)
    summarize(out_path, args.summary)


def summarize(out_path, summary_path):
    records = [json.loads(l) for l in out_path.read_text(encoding="utf-8").splitlines() if l.strip()]
    by_variant = {}
    for r in records:
        by_variant.setdefault(r["variant"], []).append(r)

    lines = ["СВОДКА A/B (temperature=0, max_tokens=512)", "=" * 60]
    header = f"{'var':4} {'n':>3} {'strict%':>7} {'lat_med':>8} {'lat_max':>8} {'cache?':>6} {'halluc':>6} {'under':>5}"
    lines.append(header)
    for variant in sorted(by_variant):
        rs = by_variant[variant]
        ok = [r for r in rs if r.get("latency_s") is not None]
        strict_pct = 100 * sum(1 for r in ok if r["strict"]) / len(ok) if ok else 0
        lats = [r["latency_s"] for r in ok]
        med = statistics.median(lats) if lats else 0
        # cache-артефакт: латентность << медианы варианта (KV-кэш llama.cpp не сбросился)
        clean = [l for l in lats if med == 0 or l >= 0.25 * med]
        suspect = len(lats) - len(clean)
        halluc = sum(len(r.get("hallucinated", [])) for r in ok)
        under = sum(len(r.get("undercounted", [])) for r in ok)
        lines.append(
            f"{variant:4} {len(rs):>3} {strict_pct:>7.0f} "
            f"{statistics.median(clean) if clean else 0:>8.0f} {max(clean) if clean else 0:>8.0f} "
            f"{suspect:>6} {halluc:>6} {under:>5}"
        )
    lines.append("")
    lines.append("По практикам (latency median / strict% / halluc / under):")
    for n in sorted({r["practice"] for r in records}):
        for variant in sorted(by_variant):
            rs = [r for r in by_variant[variant] if r["practice"] == n and r.get("latency_s") is not None]
            if not rs:
                continue
            strict_pct = 100 * sum(1 for r in rs if r["strict"]) / len(rs)
            lats = [r["latency_s"] for r in rs]
            halluc = sum(len(r.get("hallucinated", [])) for r in rs)
            under = sum(len(r.get("undercounted", [])) for r in rs)
            lines.append(
                f"  Pr_{n:<3} {variant}: {statistics.median(lats):>6.0f}s  {strict_pct:>3.0f}%  "
                f"halluc={halluc} under={under}"
            )
    text = "\n".join(lines) + "\n"
    Path(summary_path).write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
