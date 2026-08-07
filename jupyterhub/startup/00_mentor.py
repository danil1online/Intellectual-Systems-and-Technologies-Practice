"""
%%ask_mentor — магическая команда для контролируемого ИИ-помощника.

Классифицирует запрос студента:
  LAZY — просит готовое решение без усилий (штраф)
  SMART — размышляет, показывает свой код (поощрение)

Логирование: /app/logs/grading_log.json (JSON Lines)
"""

from IPython.core.magic import register_cell_magic
import json
import requests
import os
from datetime import datetime

SYSTEM_PROMPT = """Ты — строгий ментор по программированию в учебном курсе.
Классифицируй запрос студента строго по правилам:

LAZY (ленивый запрос):
- Просит написать код без усилий
- Копирует задание без попытки решения
- Просит "решить за меня", "напиши полностью"
- Не прикладывает свой код

SMART (умный запрос / вайб-кодинг):
- Прилагает свой ошибочный код и просит помочь с ошибкой
- Спрашивает про алгоритм или концепцию
- Показывает прогресс и просит направления
- Формулирует конкретный технический вопрос

Отвечай СТРОГО в формате JSON (без markdown, без объяснений):
{"category": "LAZY" или "SMART", "penalty": true или false, "reason": "короткое объяснение", "assistant_response": "ответ студенту"}
"""


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

        # Парсим JSON ответ от модели
        # Модель может обернуть в markdown code block — убираем
        if ai_content.startswith("```"):
            ai_content = ai_content.split("\n", 1)[-1]
            if ai_content.endswith("```"):
                ai_content = ai_content.rsplit("\n", 1)[0]

        ai_json = json.loads(ai_content)

        # Формируем лог
        student = os.environ.get("JUPYTERHUB_USER", "local_user")
        timestamp = datetime.now().isoformat()

        log_entry = {
            "timestamp": timestamp,
            "student": student,
            "prompt": prompt_text,
            "category": ai_json.get("category", "UNKNOWN"),
            "penalty": ai_json.get("penalty", False),
            "reason": ai_json.get("reason", ""),
        }

        # Запись лога
        log_dir = "/app/logs"
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
