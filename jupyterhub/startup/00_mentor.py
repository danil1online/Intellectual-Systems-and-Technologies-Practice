"""
%%ask_mentor — магическая команда для контролируемого ИИ-помощника.

Классифицирует запрос студента:
  LAZY — просит готовое решение без усилий (штраф)
  SMART — размышляет, показывает свой код (поощрение)

Логирование: /home/{student}/.logs/grading_log.json (JSON Lines)
"""

from IPython.core.magic import register_cell_magic
import json
import os
import re
import requests
from datetime import datetime

SYSTEM_PROMPT = r"""Ты — строгий ментор по программированию. Классифицируй строго:

LAZY (штраф):
- Фразы: "напиши полностью", "реши за меня", "дай готовое решение", "напиши программу"
- Просит готовое решение без попытки
- Нет кода, нет конкретного вопроса по конкретной ошибке
- Код тривиален/не связан с задачей

SMART (поощрение):
- Приложил код (ошибочный, неполный, с "...")
- Показывает traceback/ошибку и просит объяснить причину
- Задаёт конкретный технический вопрос по своему коду

Примеры:
"вот мой код: def sort_list(arr):\n    for i in range(len(arr)+1):...\nПочему IndexError?" → SMART
"вот мой код: a = a + 1. Что делать дальше?" → LAZY
"у меня TypeError: x='1'+2. Как исправить?" → SMART
"напиши мне программу для сортировки" → LAZY
"напиши полностью программу для сортировки пузырьком" → LAZY

Отвечай СТРОГО в формате JSON:
{"category": "LAZY" или "SMART", "penalty": true/false, "reason": "коротко", "assistant_response": "ответ"}

Требования к JSON:
- assistant_response — одна строка;
- переводы строк в ответе передавай как \n;
- двойные кавычки внутри assistant_response экранируй как \";
- если в коде ответа нужны строки, предпочитай одинарные кавычки.
"""


def _strip_code_fence(raw):
    text = (raw or "").strip()
    if not text.startswith("```"):
        return text
    lines = text.strip().splitlines()
    if lines and lines[0].strip().startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].strip().startswith("```"):
        lines = lines[:-1]
    return "\n".join(lines).strip()


def _extract_json_object(text):
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end < start:
        return ""
    return text[start:end + 1]


def _decode_json_string(value):
    try:
        return value.encode("raw_unicode_escape").decode("unicode_escape")
    except Exception:
        return (
            value.replace('\\"', '"')
            .replace('\\n', '\n')
            .replace('\\t', '\t')
            .replace('\\r', '\r')
            .replace('\\\\', '\\')
        )


def _lenient_mentor_json(raw):
    text = _strip_code_fence(raw)
    candidate = _extract_json_object(text) or text
    data = {
        "category": "UNKNOWN",
        "penalty": False,
        "reason": "",
        "assistant_response": ""
    }

    category_match = re.search(r'"category"\s*:\s*"([A-Za-z_]+)"', candidate)
    if category_match:
        data["category"] = category_match.group(1).upper()

    penalty_match = re.search(r'"penalty"\s*:\s*(true|false)', candidate, re.IGNORECASE)
    if penalty_match:
        data["penalty"] = penalty_match.group(1).lower() == "true"

    reason_match = re.search(r'"reason"\s*:\s*("(?:\\.|[^"\\])*")', candidate)
    if reason_match:
        try:
            data["reason"] = json.loads(reason_match.group(1))
        except Exception:
            data["reason"] = _decode_json_string(reason_match.group(1)[1:-1])

    marker = '"assistant_response"'
    marker_idx = candidate.rfind(marker)
    if marker_idx != -1:
        colon_idx = candidate.find(':', marker_idx + len(marker))
        open_quote_idx = candidate.find('"', colon_idx + 1) if colon_idx != -1 else -1
        closing_brace_idx = candidate.rfind('}')
        close_quote_idx = (
            candidate.rfind('"', open_quote_idx + 1, closing_brace_idx)
            if open_quote_idx != -1 and closing_brace_idx != -1 and closing_brace_idx > open_quote_idx
            else -1
        )
        if open_quote_idx != -1 and close_quote_idx != -1 and close_quote_idx > open_quote_idx:
            data["assistant_response"] = _decode_json_string(
                candidate[open_quote_idx + 1:close_quote_idx]
            )

    return data


def parse_mentor_json(raw):
    text = _strip_code_fence(raw)
    candidate = _extract_json_object(text)
    if candidate:
        try:
            data = json.loads(candidate)
            if isinstance(data, dict):
                data.setdefault("category", "UNKNOWN")
                data.setdefault("penalty", False)
                data.setdefault("reason", "")
                data.setdefault("assistant_response", "")
                return data, "strict"
        except json.JSONDecodeError:
            pass
    return _lenient_mentor_json(raw), "lenient"


@register_cell_magic
def ask_mentor(line, cell):
    """
    Кастомная магическая команда для общения с ИИ-ментором.

    Пример использования в ячейке Jupyter:
        %%ask_mentor
        Я пытаюсь написать цикл для сортировки, вот мой код:
        def sort_list(arr):
            for i in range(len(arr)+1):
                ...
        Почему возникает IndexError?
    """
    prompt_text = cell.strip()

    if not prompt_text:
        print("⚠️ Введите ваш вопрос или код в ячейку.")
        return

    # Определяем LLM endpoint
    api_key = os.environ.get("LLM_MENTOR_API_KEY", "local-api-key")
    api_base = os.environ.get("LLM_MENTOR_BASE_URL", "http://llm:8080/v1")
    model = os.environ.get("LLM_MENTOR_MODEL", "gpt-4o")

    # Если используется OpenAI API — отправляем через proxy
    try:
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }

        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt_text},
        ]

        data = {
            "model": model,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 2048,
        }

        response = requests.post(f"{api_base}/chat/completions", json=data, headers=headers, timeout=60)
        response.raise_for_status()

        result = response.json()
        ai_content = result["choices"][0]["message"]["content"].strip()

        # Парсим JSON ответ от модели: сначала строго, затем lenient.
        ai_json, parse_mode = parse_mentor_json(ai_content)

        # Формируем лог
        student = os.environ.get("JUPYTERHUB_USER", "unknown")
        timestamp = datetime.now().isoformat()

        log_entry = {
            "timestamp": timestamp,
            "student": student,
            "prompt": prompt_text,
            "category": ai_json.get("category", "UNKNOWN"),
            "penalty": ai_json.get("penalty", False),
            "reason": ai_json.get("reason", ""),
            "parse_mode": parse_mode,
        }

        # Запись лога
        log_dir = f"/home/{student}/.logs"
        log_file = os.path.join(log_dir, "grading_log.json")
        os.makedirs(log_dir, exist_ok=True)

        with open(log_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")

        # Вывод ответа студенту
        response_text = ai_json.get("assistant_response", "Ответ не получен.")
        print(f"🤖 Ментор: {response_text}")

        if ai_json.get("penalty", False):
            print("\n⚠️ Системой зафиксирован LAZY-запрос. Баллы за работу могут быть снижены.")
        else:
            print("\n✅ Запрос классифицирован как SMART — это правильное использование ИИ-помощника.")

    except json.JSONDecodeError as e:
        print(f"⚠️ Ошибка парсинга ответа ИИ: {e}")
        print(f"Сырой ответ: {ai_content if 'ai_content' in dir() else 'N/A'}")
    except requests.exceptions.ConnectionError:
        print("❌ Ошибка связи с ИИ-ментором. Проверьте подключение к LLM-серверу.")
        print(f"  Endpoint: {api_base}")
    except requests.exceptions.Timeout:
        print("⏰ Таймаут ответа ИИ-ментора. Попробуйте ещё раз.")
    except Exception as e:
        print(f"❌ Ошибка связи с ИИ-ментором: {type(e).__name__}: {e}")
