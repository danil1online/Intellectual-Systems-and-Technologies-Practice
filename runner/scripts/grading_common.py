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

import requests

CONTROL_QUESTION_TOTAL = 2.0
TASK_TOTAL = 3.0
GRADER_VERSION = "v5-per-practice-specs"

# Canonical heading is "Контрольные вопросы".
# The singular "Контрольный вопрос" and the old "Вопросы" heading are kept as
# compatibility fallbacks for already distributed student repos.
QUESTION_HEADING_RE = re.compile(
    r"^\s*##[ \t]+(?:Контрольные вопросы|Контрольный вопрос|Вопросы)[ \t]*\r?\n(.*?)(?=^\s*##[ \t]|\Z)",
    re.MULTILINE | re.DOTALL | re.IGNORECASE,
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


# ---------------------------------------------------------------------------
# Per-practice specs (practice_specs.py): компактный чек-лист вместо «вся
# методичка в промпт». Баллы считает код, LLM выдаёт только булевы.
# ---------------------------------------------------------------------------

SPEC_SYSTEM_PROMPT = (
    "Ты — строгий проверяющий практических работ курса ISTP. "
    "Ты проверяешь ТОЛЬКО пункты из списка и не придумываешь свои критерии. "
    "Ты отвечаешь ТОЛЬКО одним JSON-объектом, без markdown."
)

DEFAULT_SPEC_REPORT_CHARS = 24000


def build_spec_prompt(spec, practice_num, report_text, max_report_chars=DEFAULT_SPEC_REPORT_CHARS):
    """Компактный промпт по spec: шаги задания + вопросы с якорями + отчёт.

    LLM выдаёт только компактные булевы массивы (надёжно парсится даже малыми
    моделями); grounding и баллы считает код — normalize_spec_payload.
    """
    tasks_block = "\n".join(f"{i + 1}. {task['text']}" for i, task in enumerate(spec["tasks"]))
    task_rules = "\n".join(f"- {rule}" for rule in spec.get("task_rules", []))

    questions = spec.get("questions", [])
    if questions:
        q_lines = []
        for i, q in enumerate(questions):
            anchors = "\n".join(f"   - {anchor}" for anchor in q["anchors"])
            q_lines.append(f"{i + 1}. {q['text']}\n   Ключевые концепты верного ответа:\n{anchors}")
        questions_block = "\n".join(q_lines)
        question_rules = "\n".join(f"- {rule}" for rule in spec.get("question_rules", []))
        questions_section = f"""
=== КОНТРОЛЬНЫЕ ВОПРОСЫ ({len(questions)}) ===
{questions_block}

Правила проверки ответов:
{question_rules}
"""
        questions_json = f'"questions": [true/false по порядку, ровно {len(questions)} значений], '
    else:
        questions_section = ""
        questions_json = ""

    report = (report_text or "").strip()
    if not report:
        report = "(файл отчёта не найден или пуст)"
    elif len(report) > max_report_chars:
        report = report[:max_report_chars] + "\n…[отчёт обрезан]"

    # ВАЖНО: отчёт стоит ПЕРВЫМ — малые модели хуже удерживают контекст,
    # когда длинные инструкции идут до данных (проверено A/B на qwen2.5-3b).
    return f"""=== ОТЧЁТ СТУДЕНТА ===
{report}

Проверь работу студента по практической работе №{practice_num} «{spec['title']}» по тексту отчёта ВЫШЕ, пункт за пунктом.

=== ШАГИ ЗАДАНИЯ ({len(spec['tasks'])}) ===
{tasks_block}

ПРАВИЛА ПРОВЕРКИ ЗАДАНИЯ:
{task_rules}
{questions_section}
Ответь ТОЛЬКО одним JSON-объектом, без markdown и без пояснений до/после:
{{"tasks": [true/false по порядку, ровно {len(spec['tasks'])} значений], {questions_json}"feedback": "<1-2 предложения на русском>", "issues": ["..."], "recommendations": ["..."]}}

Порядок значений в массивах совпадает с порядком пунктов выше. Если пункт не выполнен или ответа нет — false."""


def validate_spec_payload(data, spec):
    """Валидация JSON LLM под spec. Пустой список — ок, иначе список ошибок."""
    if not isinstance(data, dict):
        return ["ответ LLM не является JSON-объектом"]
    errors = []

    n_tasks = len(spec["tasks"])
    tasks = data.get("tasks")
    if tasks is None:
        errors.append(f'нет массива "tasks" — нужен массив ровно из {n_tasks} значений true/false по порядку шагов')
    elif not isinstance(tasks, list) or len(tasks) != n_tasks:
        got = len(tasks) if isinstance(tasks, list) else "не массив"
        errors.append(f'массив "tasks" должен содержать ровно {n_tasks} значений true/false, получено: {got}')

    questions = spec.get("questions", [])
    if questions:
        n_q = len(questions)
        answers = data.get("questions")
        if answers is None:
            errors.append(f'нет массива "questions" — нужен массив ровно из {n_q} значений true/false по порядку вопросов')
        elif not isinstance(answers, list) or len(answers) != n_q:
            got = len(answers) if isinstance(answers, list) else "не массив"
            errors.append(f'массив "questions" должен содержать ровно {n_q} значений true/false, получено: {got}')
    return errors


# Заголовок блока с ответами на контрольные вопросы: разделитель между
# «выполнением задания» (где ищутся команды) и «ответами» (где ищутся цитаты).
ANSWERS_BLOCK_RE = re.compile(
    r"^\s*(?:#{1,6}[ \t]+|\*{1,3}[ \t]*)?"
    r"(?:[Кк]онтрольные вопросы|[Оо]тветы[ \t]+на[ \t]+[Кк]онтрольные вопросы)"
    r"[ \t]*\*{0,3}[ \t]*$",
    re.MULTILINE,
)


def _norm_text(text):
    return re.sub(r"\s+", " ", (text or "")).strip().lower()


def _work_section(report_text):
    """Часть отчёта до блока ответов: здесь ищутся команды задания."""
    text = report_text or ""
    match = ANSWERS_BLOCK_RE.search(text)
    if match:
        return text[: match.start()]
    return text


ANSWER_ITEM_RE = re.compile(r"^\s*(\d{1,2})\s*[)\.:][ \t]*(.*)$")


def extract_answer_items(report_text):
    """Детерминированный разбор блока с ответами: {номер вопроса: текст пункта}."""
    text = report_text or ""
    match = ANSWERS_BLOCK_RE.search(text)
    if not match:
        return {}
    block = text[match.end():]
    lines = block.splitlines()
    items = {}
    current_num = None
    buf = []
    for line in lines:
        item_match = ANSWER_ITEM_RE.match(line)
        if item_match:
            if current_num is not None:
                items[current_num] = "\n".join(buf).strip()
            current_num = int(item_match.group(1))
            buf = [line]
        elif current_num is not None:
            # Сброс в следующем заголовке раздела (## ...) — блок ответов закончился
            if re.match(r"^\s*#{1,6}[ \t]", line):
                items[current_num] = "\n".join(buf).strip()
                current_num = None
                buf = []
            else:
                buf.append(line)
    if current_num is not None:
        items[current_num] = "\n".join(buf).strip()
    return {num: value for num, value in sorted(items.items())}


def _answer_present(item_text, question_text, margin=10):
    """Ответ «есть», если в пункте есть содержимое сверх самого вопроса."""
    if not item_text:
        return False
    nonempty_lines = [line for line in item_text.splitlines() if line.strip()]
    if len(nonempty_lines) >= 2:
        return True
    return len(item_text.strip()) > len((question_text or "").strip()) + margin


def _task_llm_flag(item):
    if isinstance(item, dict):
        return _as_bool(item.get("done", False))
    return _as_bool(item)


def _answer_keywords_ok(item_text, question, min_keywords=2):
    """Проверка ответа по ключевым словам концепта: в ответе должно быть не
    меньше min_keywords слов из spec['keywords'][i] (выбираются так, чтобы
    они не входили в текст самого вопроса — чистое копирование вопроса
    их не содержит)."""
    keywords = question.get("keywords") or []
    if not keywords:
        return True
    text = _norm_text(item_text)
    hits = sum(1 for keyword in keywords if keyword.lower() in text)
    return hits >= min_keywords


def _task_regex_ok(task, report_text):
    markers = task.get("markers") or []
    return any(re.search(marker, report_text, re.IGNORECASE) for marker in markers)


def normalize_spec_payload(raw, spec, report_text):
    """Считать баллы по булевым LLM с детерминированным grounding из отчёта.

    task[i]     = LLM_done[i] AND найден в тексте задания отчёта любой marker
                  команды шага (команды из блока вопросов не засчитываются)
    question[j] = LLM_correct[j] AND в блоке ответов найден пункт j
                   с содержимым сверх самого вопроса AND в ответе есть
                   ключевые слова концепта (spec['keywords'], порог min_keywords)

    Галлюцинация LLM («выполнено» без команды / «верно» без ответа /
    «верно» для мусорного ответа) → false.
    """
    result = dict(raw) if isinstance(raw, dict) else {}
    report_text = report_text or ""
    work_text = _work_section(report_text)

    tasks_total = len(spec["tasks"])
    raw_tasks = result.get("tasks") if isinstance(result.get("tasks"), list) else []
    task_flags, task_llm_flags, task_regex_flags = [], [], []
    for i, task in enumerate(spec["tasks"]):
        item = raw_tasks[i] if i < len(raw_tasks) else None
        llm_done = _task_llm_flag(item)
        regex_ok = _task_regex_ok(task, work_text)
        task_flags.append(bool(llm_done and regex_ok))
        task_llm_flags.append(llm_done)
        task_regex_flags.append(regex_ok)
    tasks = task_flags

    done_count = sum(1 for value in tasks if value)
    task_score = round(TASK_TOTAL * done_count / tasks_total, 6)

    questions = spec.get("questions", [])
    raw_questions = result.get("questions") if isinstance(result.get("questions"), list) else []
    answer_items = extract_answer_items(report_text)
    min_keywords = int(spec.get("min_keywords", 2))
    answers, question_llm_flags, question_present_flags, question_keyword_flags = [], [], [], []
    for i, question in enumerate(questions):
        item = raw_questions[i] if i < len(raw_questions) else None
        llm_correct = _as_bool(item)
        item_text = answer_items.get(i + 1, "")
        present = _answer_present(item_text, question.get("text", ""))
        keywords_ok = _answer_keywords_ok(item_text, question, min_keywords)
        answers.append(bool(llm_correct and present and keywords_ok))
        question_llm_flags.append(llm_correct)
        question_present_flags.append(present)
        question_keyword_flags.append(keywords_ok)
    if questions:
        correct_count = sum(1 for value in answers if value)
        question_score = round(CONTROL_QUESTION_TOTAL * correct_count / len(questions), 6)
    else:
        correct_count = 0
        question_score = 0.0

    final_score = int(max(0, min(5, math.floor(task_score + question_score + 0.5))))

    done_idx = [str(i + 1) for i, value in enumerate(tasks) if value]
    extra = f"Задание: выполнены шаги {', '.join(done_idx) if done_idx else '—'} из {tasks_total} ({task_score:.2f}/3)"
    if questions:
        correct_idx = [str(i + 1) for i, value in enumerate(answers) if value]
        wrong_idx = [str(i + 1) for i, value in enumerate(answers) if not value]
        extra += (
            f"; контрольные вопросы: верные {', '.join(correct_idx) if correct_idx else '—'}, "
            f"неверные/отсутствующие {', '.join(wrong_idx) if wrong_idx else '—'} ({question_score:.2f}/2)"
        )
    extra += f"; итог {final_score}/5."

    result["tasks"] = tasks
    result["task_llm_flags"] = task_llm_flags
    result["task_regex_flags"] = task_regex_flags
    result["done_count"] = done_count
    result["total_tasks"] = tasks_total
    result["task_score"] = task_score
    result["score"] = final_score
    if questions:
        result["control_questions"] = answers
        result["question_llm_flags"] = question_llm_flags
        result["question_present_flags"] = question_present_flags
        result["question_keyword_flags"] = question_keyword_flags
        result["question_score"] = question_score
        result["answered_count"] = correct_count
        result["total_questions"] = len(questions)
        result["answered_idx"] = [str(i + 1) for i, value in enumerate(answers) if value]
        result["not_answered_idx"] = [str(i + 1) for i, value in enumerate(answers) if not value]

    feedback = result.get("feedback") or result.get("comment") or ""
    if feedback and extra not in feedback:
        result["feedback"] = f"{feedback}. {extra}"
    else:
        result["feedback"] = extra

    for key in ("issues", "recommendations"):
        if key not in result or result[key] is None:
            result[key] = []

    return result


def chat_completion(prompt, system, base_url, api_key, model,
                    temperature=0.1, max_tokens=2048, timeout=180):
    """Один запрос к OpenAI-совместимому /chat/completions → raw content."""
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    data = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": prompt},
        ],
        "temperature": temperature,
        "max_tokens": max_tokens,
    }
    response = requests.post(
        f"{base_url}/chat/completions", json=data, headers=headers, timeout=timeout,
    )
    response.raise_for_status()
    return response.json()["choices"][0]["message"]["content"]


def evaluate_with_llm_spec(prompt, spec, base_url, api_key, model,
                           max_attempts=3, max_tokens=4096):
    """Оценка по spec: запрос → парсинг → валидация, повторы при ошибках.

    Повтор при: неверном JSON, неверной длине массивов, ошибке запроса.
    Возвращает (payload, meta). payload — {} при полной ошибке;
    meta — parse_mode, attempts, preview, retry_errors и т.п.
    """
    active_prompt = prompt
    parsed = {}
    meta = {"attempts": 0, "parse_mode": "failed"}
    for attempt in range(1, max_attempts + 1):
        meta["attempts"] = attempt
        try:
            content = chat_completion(
                active_prompt, SPEC_SYSTEM_PROMPT, base_url, api_key, model,
                max_tokens=max_tokens,
            )
        except Exception as exc:
            meta["parse_mode"] = "request-error"
            meta["error"] = str(exc)
            if attempt < max_attempts:
                active_prompt = (
                    prompt
                    + "\n\n=== ОШИБКА В ТВОЁМ ПРЕДЫДУЩЕМ ОТВЕТЕ ===\n"
                    + f"- ответ не получен: {exc}"
                    + "\nПовтори ответ ТОЛЬКО в требуемом JSON-формате."
                )
                continue
            return {}, meta

        parsed, parse_mode = parse_llm_json(content)
        meta["parse_mode"] = parse_mode
        if parse_mode != "strict":
            meta["llm_raw_preview"] = llm_raw_preview(content)
        errors = [] if parsed else ["ответ не распознан как JSON — повтори полный JSON-объект"]
        if parsed:
            errors = validate_spec_payload(parsed, spec)
        if not errors:
            return parsed, meta

        meta["retry_errors"] = errors
        if attempt < max_attempts:
            meta["parse_mode"] = f"invalid-attempt-{attempt}"
            active_prompt = (
                prompt
                + "\n\n=== ОШИБКА В ТВОЁМ ПРЕДЫДУЩЕМ ОТВЕТЕ ===\n"
                + "\n".join(f"- {error}" for error in errors)
                + "\nПовтори ответ ТОЛЬКО одним полным JSON-объектом в требуемом формате."
            )
    meta["parse_mode"] = "lenient-after-retry"
    return parsed, meta
