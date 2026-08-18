#!/usr/bin/env python3
"""Shared helpers for ISTP LLM grading.

Provides:
- reading requirement docs,
- extracting control questions from methodological docs,
- deterministic scoring for control questions,
- normalization of LLM JSON payloads.
"""

import math
import re
from pathlib import Path

CONTROL_QUESTION_TOTAL = 2.0
GRADER_VERSION = "v3-pr2-pr3-hidden-answers"

# Canonical heading is "Контрольные вопросы".
# The old "Вопросы" heading is kept as a compatibility fallback for already
# distributed student repos.
QUESTION_HEADING_RE = re.compile(
    r"^\s*##[ \t]+(?:Контрольные вопросы|Вопросы)[ \t]*\r?\n(.*?)(?=^\s*##[ \t]|\Z)",
    re.MULTILINE | re.DOTALL,
)
QUESTION_LINE_RE = re.compile(r"^\s*\d+[.)][ \t]+(.+?)[ \t]*$", re.MULTILINE)


def read_requirement_text(path):
    """Read requirement doc text from path. Empty string on any problem."""
    if not path:
        return ""
    p = Path(path)
    try:
        if not p.exists() or not p.is_file():
            return ""
        return p.read_text(encoding="utf-8")
    except Exception:
        return ""


def extract_control_questions(requirement_text):
    """Extract numbered questions from a '## Контрольные вопросы' block."""
    if not requirement_text:
        return []
    match = QUESTION_HEADING_RE.search(requirement_text)
    if not match:
        return []
    questions = []
    for line in match.group(1).splitlines():
        qm = QUESTION_LINE_RE.match(line)
        if not qm:
            continue
        question = qm.group(1).strip()
        if question:
            questions.append(question)
    return questions


def format_question_block(questions):
    if not questions:
        return ""
    return "\n".join(f"{i + 1}. {q}" for i, q in enumerate(questions))


def _as_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "y", "да"}
    return False


def _clamp_int(value, low, high):
    try:
        x = int(round(float(value)))
    except (TypeError, ValueError):
        x = 0
    return max(low, min(high, x))


def _normalize_answers(raw_answers, expected_count):
    if not isinstance(raw_answers, list):
        return [False] * expected_count
    answers = []
    for i in range(expected_count):
        value = raw_answers[i] if i < len(raw_answers) else False
        answers.append(_as_bool(value))
    return answers


def compute_question_score(answers, total=CONTROL_QUESTION_TOTAL):
    if not answers:
        return 0.0, 0, 0
    weight = total / len(answers)
    answered_count = sum(1 for value in answers if value)
    return round(answered_count * weight, 6), answered_count, len(answers)


def normalize_grade_payload(raw, questions):
    """Normalize LLM payload and, when questions exist, compute final score locally.

    Returns (payload, questions_used: bool).
    """
    result = dict(raw) if isinstance(raw, dict) else {}

    if not questions:
        score = _clamp_int(result.get("score", result.get("task_score", 0)), 0, 5)
        result["score"] = score
        return result, False

    task_score = _clamp_int(result.get("task_score", result.get("score", 0)), 0, 3)
    answers = _normalize_answers(result.get("control_questions", []), len(questions))
    question_score, answered_count, total_questions = compute_question_score(answers)
    final_score = int(max(0, min(5, math.floor(task_score + question_score + 0.5))))

    answered_idx = [str(i + 1) for i, value in enumerate(answers) if value]
    not_idx = [str(i + 1) for i, value in enumerate(answers) if not value]
    extra = (
        f"Контрольные вопросы: отвечены {', '.join(answered_idx) if answered_idx else 'нет'}, "
        f"не отвечены {', '.join(not_idx) if not_idx else 'нет'}; "
        f"вопросы {question_score:.2f}/2, задача {task_score}/3, итог {final_score}/5."
    )

    result["task_score"] = task_score
    result["control_questions"] = answers
    result["question_score"] = question_score
    result["answered_count"] = answered_count
    result["total_questions"] = total_questions
    result["score"] = final_score
    result["answered_idx"] = answered_idx
    result["not_answered_idx"] = not_idx

    feedback = result.get("feedback") or result.get("comment") or ""
    if feedback and extra not in feedback:
        result["feedback"] = f"{feedback}. {extra}"
    else:
        result["feedback"] = extra

    for key in ("issues", "recommendations"):
        if key not in result or result[key] is None:
            result[key] = []

    return result, True
