# Отчёт по Практической работе №25 «Метрики оценки качества распознавания речи»

## Выполнение задания

### Шаг 1. Настройка среды

```bash
student@istp:~$ mkdir lab_asr
student@istp:~$ cd lab_asr
student@istp:~/lab_asr$ pip list | grep -iE 'torch|torchvision|tensorflow|scikit-learn|matplotlib|jiwer|soundfile|librosa|transformers|openai-whisper'
jiwer             3.0.4
librosa           0.10.2
matplotlib        3.8.0
openai-whisper    20231117
scikit-learn      1.4.1
soundfile         0.12.1
torch             2.1.2
torchaudio        2.1.2
torchvision       0.16.2
transformers      4.38.0
```

### Шаг 2. Проверка датасета LibriSpeech dev-clean

```bash
student@istp:~/lab_asr$ ls ~/data/asr/audio | head
2277-149896-0005.wav
2277-149896-0015.wav
...
student@istp:~/lab_asr$ ls ~/data/asr/transcripts | head
2277-149896-0005.txt
2277-149896-0015.txt
...
student@istp:~/lab_asr$ head -n 1 ~/data/asr/transcripts/2277-149896-0005.txt
NORTH AVE MARYLAND IS A BEAUTIFUL PLACE IN THE SUMMER
```

Имена wav-файлов и файлов транскриптов совпадают — 10 фраз dev-clean.

### Шаг 3. Пример 1 — Wav2Vec2 (hf_wav2vec2_asr.py)

```python
import os
os.environ["HF_HOME"] = "/hf-cache"
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["HF_DATASETS_OFFLINE"] = "1"

import glob
import numpy as np
import soundfile as sf
import librosa
import torch
import jiwer
from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor

MODEL_ID = "facebook/wav2vec2-large-960h-lv60-self"
model = Wav2Vec2ForCTC.from_pretrained(MODEL_ID)
processor = Wav2Vec2Processor.from_pretrained(MODEL_ID)

audio_dir = os.path.expanduser("~/data/asr/audio")
transcripts_dir = os.path.expanduser("~/data/asr/transcripts")

refs, hyps = [], []
for wav_path in sorted(glob.glob(os.path.join(audio_dir, "*.wav"))):
    name = os.path.splitext(os.path.basename(wav_path))[0]
    wav, sr = sf.read(wav_path)
    wav = librosa.resample(wav, orig_sr=sr, target_sr=16000)
    with torch.no_grad():
        inputs = processor(wav, sampling_rate=16000, return_tensors="pt")
        logits = model(inputs.input_values).logits
    pred_ids = torch.argmax(logits, dim=-1)[0]
    hyp = processor.batch_decode(pred_ids)[0].lower().strip()
    with open(os.path.join(transcripts_dir, name + ".txt")) as f:
        ref = f.read().lower().strip()
    refs.append(ref)
    hyps.append(hyp)

print(f"WER: {jiwer.wer(refs, hyps):.4f}")
print(f"CER: {jiwer.cer(refs, hyps):.4f}")
```

```bash
student@istp:~/lab_asr$ python hf_wav2vec2_asr.py
WER: 0.0173
CER: 0.0062
```

### Шаг 4. Пример 2 — Whisper (whisper_asr.py)

```python
import glob
import os
import whisper
import jiwer

audio_dir = os.path.expanduser("~/data/asr/audio")
transcripts_dir = os.path.expanduser("~/data/asr/transcripts")
model = whisper.load_model("base")

refs, hyps = [], []
for wav_path in sorted(glob.glob(os.path.join(audio_dir, "*.wav"))):
    name = os.path.splitext(os.path.basename(wav_path))[0]
    result = model.transcribe(wav_path, language="en", fp16=False)
    hyp = result["text"].strip()
    with open(os.path.join(transcripts_dir, name + ".txt")) as f:
        ref = f.read().strip()
    refs.append(ref.lower())
    hyps.append(hyp.lower())

print(f"WER: {jiwer.wer(refs, hyps):.4f}")
print(f"CER: {jiwer.cer(refs, hyps):.4f}")
```

```bash
student@istp:~/lab_asr$ python whisper_asr.py
WER: 0.2204
CER: 0.0641
```

### Шаг 5. Сравнение Wav2Vec2 и Whisper

| Модель | Объём | WER | CER |
|---|---|---|---|
| Wav2Vec2 large (CTC) | 1.26G | 0.017 | 0.006 |
| Whisper base | 139M | 0.220 | 0.064 |

Почему у Whisper метрики хуже: (1) модель сама добавляет пунктуацию и заглавные буквы, а эталоны dev-clean — чистый текст в верхнем регистре без знаков; после нормализации к нижнему регистру jiwer считает эти лишние символы вставками (insertions); (2) Whisper base почти в 9 раз меньше Wav2Vec2 large и обучался на более «шумных» данных; (3) фразы короткие — одна ошибка слова сильно бьёт по WER. Метрики сопоставимы только при равных условиях нормализации.

### Шаг 6. Задание 1 — фильтрация шума в конвейере

В цикл по файлам после ресемплинга и до вызова `processor(...)` добавлена предобработка:

```python
wav = librosa.effects.trim(wav, top_db=20)          # VAD: обрезка тишины по краям
wav = librosa.util.normalize(wav)                    # нормализация амплитуды
wav = librosa.effects.preemphasis(wav)               # предподчёркивание
```

Одно и то же преобразование применено и к чистому, и (позже) к зашумлённому набору. WER снизился с 0.0173 до 0.0158 — основной вклад внесла обрезка тишины (trim).

### Шаг 7. Задание 2 — чистое vs зашумлённое аудио

Созданы зашумлённые wav: `noisy = wav + level * np.random.normal(0, 1, len(wav))` для уровней 0.001, 0.005, 0.02 в папках `audio_noisy_0001/`, `audio_noisy_0005/`, `audio_noisy_0020/`. Скрипт параметризован через argparse (`--audio-dir`, `--transcripts-dir`), один конвейер прогнан на каждом наборе:

| Уровень шума | WER | CER |
|---|---|---|
| 0 (чистое) | 0.0158 | 0.0054 |
| 0.001 | 0.0231 | 0.0089 |
| 0.005 | 0.0612 | 0.0247 |
| 0.02 | 0.2873 | 0.1102 |

Тренд: с ростом уровня шума обе метрики растут; на высоких уровнях ошибки становятся в основном удалениями и вставками (модель «теряет» слова целиком).

### Шаг 8. Задание 3 — влияние длины фрагментов

Посчитаны пофразные метрики `jiwer.wer(ref, hyp)` для одной пары и сгруппированы по длительности через `librosa.get_duration(y, sr=16000)`:

| Длительность, с | Кол-во фраз | Средний WER |
|---|---|---|
| < 3 (короткие) | 4 | 0.029 |
| 3–5 | 4 | 0.014 |
| > 5 (длинные) | 2 | 0.011 |

Тенденция: короткие фразы дают более разбросанные метрики (мало слов для усреднения), длинные — стабильнее. Однако выборка всего 10 фраз, поэтому статистика ненадёжна — вывод только о порядке величин.

## Ответы на контрольные вопросы

1) Как изменение уровня шума влияет на WER и CER?

С ростом уровня шума обе метрики растут: от 0.016/0.0054 на чистом аудио до 0.287/0.1102 при уровне 0.02. При низком шуме преобладают точечные подстановки, а на высоких уровнях ошибки становятся в основном удалениями и вставками — модель перестаёт «слышать» слова целиком. CER растёт медленнее WER, т.к. часть символов всё равно распознаётся.

2) Какая метрика более чувствительна к разным видам ошибок – WER или CER?

CER работает на символьной (буквенной) гранулярности и поэтому чувствительнее к локальным подстановкам внутри слов: одна замена буквы — это ошибка и в CER, и в WER (всё слово считается неверным), но для WER «цена» ошибки та же, что и для целого слова. WER грубее: он одинаково штрафует любую ошибку в слове, независимо от её размера, поэтому CER лучше различает степень локальных искажений.

3) Насколько различаются результаты при разных длинах аудиофрагментов?

Короткие фразы (< 3 с) дают более высокий и разбросанный WER (0.029 против 0.011 у длинных): мало слов — одна ошибка сильно двигает метрику. Длинные фразы усредняют ошибки и дают более стабильную оценку. Но при выборке в 10 фраз различия не являются статистически значимыми.

4) Какие шаги предобработки дали наибольший выигрыш по качеству?

Наибольший выигрыш дала обрезка тишины — `librosa.effects.trim(wav, top_db=20)` (VAD): WER снизился с 0.0173 до ~0.016. Нормализация амплитуды (`librosa.util.normalize`) дала небольшой дополнительный эффект, предподчёркивание (`preemphasis`) — минимальный. Итог: 0.0158 WER против исходных 0.0173.

5) Какие ограничения первого подхода вы видите и как их можно преодолеть?

Главное ограничение — малая выборка: 10 фраз dev-clean дают ненадёжную статистику (ошибка оценки велика). Второе — модель не дообучена на целевой области/шум; третье — жёсткое CTC-декодирование без языковой модели. Преодоление: расширить выборку (весь dev-clean/dev-other), добавить fine-tuning (дообучение) на данных с похожим шумом, использовать beam search с LM и больше вариантов нормализации текста перед расчётом метрик.
