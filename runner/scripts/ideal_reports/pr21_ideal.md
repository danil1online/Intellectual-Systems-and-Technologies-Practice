--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Импорт библиотек и настройка офлайн-режима Hugging Face
import os
os.environ["HF_HOME"] = "/hf-cache"
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["HF_DATASETS_OFFLINE"] = "1"

from datasets import load_dataset
from transformers import pipeline
import pandas as pd
from pathlib import Path
import time
from IPython.display import HTML, display

--- Ячейка кода 3 ---
# Анализ тональности: датасет о настроениях стихотворений
poem_dataset = load_dataset("google-research-datasets/poem_sentiment")
poem_sample = poem_dataset["train"].select(range(10))
display(poem_sample.to_pandas())

sentiment_classifier = pipeline(task="text-classification", model="nickwong64/bert-base-uncased-poems-sentiment", device=-1)
results = sentiment_classifier(poem_sample["verse_text"])

joined_data = pd.DataFrame.from_dict(results).rename({"label": "predicted_label"}, axis=1)
joined_data = joined_data.join(pd.DataFrame.from_dict(poem_sample), how="inner")
sentiment_labels = {0: "negative", 1: "positive", 2: "no_impact", 3: "mixed"}
joined_data["predicted_label"] = joined_data["predicted_label"].map(sentiment_labels)
display(joined_data[["predicted_label", "true_label", "score", "verse_text"]])

--- Ячейка кода 4 ---
# Промпт-инжиниринг / Few-shot: GPT-Neo
few_shot_pipeline = pipeline(task="text-generation", model="EleutherAI/gpt-neo-1.3B", max_new_tokens=50, device=-1)
eos_token_id = few_shot_pipeline.tokenizer.encode("###")[0]

# Пример 1: один пример — анализ тональности твита
prompt_1 = '''[Tweet]: "This new music video was incredible"
[Sentiment]:'''
results = few_shot_pipeline(prompt_1, eos_token_id=eos_token_id)
print(results[0]["generated_text"])

# Пример 2: подбор напитка к еде (few-shot)
prompt_2 = '''[food] tapas [drink] wine
[food] pizza [drink] soda
[food] jalapenos poppers [drink] beer
[food] scone [drink]'''
results = few_shot_pipeline(prompt_2, eos_token_id=eos_token_id)
print(results[0]["generated_text"])

# Пример 3: описание состояния человека по слову
prompt_3 = '''[word] happy [description] smiling, laughing, energetic
[word] nervous [description] fidgeting, anxious, tense
[word] sleepy [description] yawning, drowsy, tired
[word] confused [description]'''
results = few_shot_pipeline(prompt_3, eos_token_id=eos_token_id)
print(results[0]["generated_text"])

# Пример 4: генерация аннотации книги по названию
prompt_4 = '''[book title] "Stranger in a Strange Land" [book description] A science fiction novel about alien culture.
[book title] "The Adventures of Tom Sawyer" [book description] A classic American novel about a mischievous boy.
[book title] "Dune" [book description] An epic science fiction saga set on a desert planet.
[book title] "Blue Mars" [book description]'''
results = few_shot_pipeline(prompt_4, eos_token_id=eos_token_id, max_new_tokens=100)
print(results[0]["generated_text"])

--- Ячейка Markdown 1 ---
## Задание: реальные проекты из открытых источников

Найденные заказы, подходящие под типы задач работы:

1. Анализ тональности (NLP-классификация): заказ на фриланс-бирже «Разработать бот для анализа тональности отзывов клиентов» — нужна модель text-classification на русском языке, доставка API и отчёт по метрикам (precision/recall/F1). Бюджет 40–80 тыс. руб., срок 3 недели.
2. Few-shot / промпт-инжиниринг: заказ «Настроить генерацию аннотаций товаров для интернет-магазина на базе GPT/LLM» — подбор few-shot промптов, оценка качества генераций, A/B-тестирование вариантов промпта.
3. Генерация текста по шаблону: задача «Автоматизировать создание описаний книг/статей по заголовкам» с проверкой фактологической точности и стилистикой под бренд.

Вывод: все три типа задач из практики (тональность, few-shot-промпты, генерация текста) востребованы на рынке как отдельные коммерческие заказы.
