#!/usr/bin/env python3
"""Shared helpers for ISTP LLM grading.

Provides:
- reading requirement docs,
- extracting control questions from methodological docs,
- deterministic scoring for control questions,
- normalization of LLM JSON payloads.
"""

import json
import math
import re
from pathlib import Path

CONTROL_QUESTION_TOTAL = 2.0
GRADER_VERSION = "v4-robust-llm-json"

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


def _strip_code_fence(raw):
    text = (raw or "").strip()
    if not text.startswith("```"):
        return text
    lines = text.splitlines()
    if lines and lines[0].strip().startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].strip().startswith("```"):
        lines = lines[:-1]
    return "\n".join(lines).strip()


def _extract_balanced_json_object(text):
    start = text.find("{")
    if start == -1:
        return ""
    depth = 0
    in_string = False
    escape = False
    for i in range(start, len(text)):
        ch = text[i]
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
        elif ch == '"':
            in_string = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    return ""


def _extract_json_candidate(text):
    text = (text or "").strip()
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end != -1 and end > start:
        return text[start:end + 1]
    return text


def _remove_trailing_commas(text):
    result = []
    in_string = False
    escape = False
    for i, ch in enumerate(text):
        if in_string:
            result.append(ch)
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
        elif ch == '"':
            in_string = True
            result.append(ch)
        elif ch == ",":
            j = i + 1
            while j < len(text) and text[j].isspace():
                j += 1
            if j < len(text) and text[j] in "}]":
                continue
            result.append(ch)
        else:
            result.append(ch)
    return "".join(result)


def _decode_json_string(value):
    try:
        return value.encode("raw_unicode_escape").decode("unicode_escape")
    except Exception:
        return (
            value.replace('\\"', '"')
            .replace("\\n", "\n")
            .replace("\\t", "\t")
            .replace("\\r", "\r")
            .replace("\\\\", "\\")
        )


def _extract_int_field(candidate, key):
    m = re.search(rf'"{key}"\s*:\s*(-?\d+(?:\.\d+)?)', candidate or "")
    if not m:
        return None
    try:
        return int(round(float(m.group(1))))
    except (TypeError, ValueError):
        return None


def _extract_bool_field(candidate, key):
    m = re.search(rf'"{key}"\s*:\s*(true|false)', candidate or "", re.IGNORECASE)
    if not m:
        return None
    return m.group(1).lower() == "true"


def _extract_string_field(candidate, key):
    m = re.search(rf'"{key}"\s*:\s*("(?:\\.|[^"\\])*")', candidate or "")
    if not m:
        return None
    raw = m.group(1)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return _decode_json_string(raw[1:-1])


def _extract_array_raw(candidate, key):
    m = re.search(rf'"{key}"\s*:\s*\[', candidate or "")
    if not m:
        return None
    start = m.end()
    end = candidate.find("]", start)
    next_key = re.search(r'"[A-Za-z_]+"?\s*:', candidate[start:])
    if next_key:
        next_pos = start + next_key.start()
        if end == -1 or next_pos < end:
            end = next_pos
    if end == -1:
        end = len(candidate)
    return candidate[start:end]


def _extract_bool_array(candidate, key):
    raw = _extract_array_raw(candidate, key)
    if raw is None:
        return None
    flags = re.findall(r"\b(true|false)\b", raw, re.IGNORECASE)
    if flags:
        return [flag.lower() == "true" for flag in flags]
    numbers = re.findall(r"\b(\d+)\b", raw)
    if numbers:
        return [int(value) != 0 for value in numbers]
    return []


def _extract_string_array(candidate, key):
    raw = _extract_array_raw(candidate, key)
    if raw is None:
        return None
    try:
        data = json.loads(f"[{raw}]")
        if isinstance(data, list):
            return [str(item) for item in data]
    except json.JSONDecodeError:
        pass
    values = re.findall(r'"((?:\\.|[^"\\])*)"', raw)
    if values:
        return [_decode_json_string(value) for value in values]
    return []


def _lenient_grader_json(raw):
    text = _strip_code_fence(raw)
    candidate = _extract_json_candidate(text)
    data = {}

    for key in ("score", "task_score"):
        value = _extract_int_field(candidate, key)
        if value is not None:
            data[key] = value

    for key in ("executes", "has_explanation"):
        value = _extract_bool_field(candidate, key)
        if value is not None:
            data[key] = value

    feedback = _extract_string_field(candidate, "feedback")
    if feedback is None:
        feedback = _extract_string_field(candidate, "comment")
    if feedback is not None:
        data["feedback"] = feedback

    control = _extract_bool_array(candidate, "control_questions")
    if control is not None:
        data["control_questions"] = control

    for key in ("issues", "recommendations"):
        value = _extract_string_array(candidate, key)
        if value is not None:
            data[key] = value

    return data


def _try_parse_json_candidate(candidate):
    if not candidate:
        return None, None
    try:
        data = json.loads(candidate)
        if isinstance(data, dict):
            return data, "strict"
    except json.JSONDecodeError:
        pass
    fixed = _remove_trailing_commas(candidate)
    if fixed != candidate:
        try:
            data = json.loads(fixed)
            if isinstance(data, dict):
                return data, "strict-fixed-trailing-comma"
        except json.JSONDecodeError:
            pass
    return None, None


def parse_llm_json(raw):
    """Parse LLM output for graders.

    Returns (dict, parse_mode). On total failure returns ({}, "failed").
    """
    text = _strip_code_fence(raw)
    balanced = _extract_balanced_json_object(text)
    data, parse_mode = _try_parse_json_candidate(balanced)
    if data is not None:
        return data, parse_mode

    candidate = _extract_json_candidate(text)
    if candidate != balanced:
        data, parse_mode = _try_parse_json_candidate(candidate)
        if data is not None:
            if parse_mode == "strict":
                return data, "strict-extracted"
            return data, parse_mode

    data = _lenient_grader_json(raw)
    if data:
        return data, "lenient"
    return {}, "failed"


def llm_raw_preview(raw, limit=2000):
    text = (raw or "").replace("\n", " ").strip()
    return text[:limit]


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
