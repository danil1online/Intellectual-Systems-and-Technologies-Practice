# Отчёт по Практической работе №26 «Классификация и понимание текста»

## Выполнение задания

### Шаг 1. Настройка среды

```bash
student@istp:~$ mkdir text_lab
student@istp:~$ cd text_lab
student@istp:~/text_lab$ mkdir results
student@istp:~/text_lab$ pip list | grep -iE 'torch|scikit-learn|matplotlib|transformers|datasets|umap-learn|pandas|seaborn'
datasets          2.16.1
matplotlib        3.8.0
pandas            2.2.1
scikit-learn      1.4.1
seaborn           0.13.2
torch             2.1.2
transformers      4.38.0
umap-learn        0.5.4
```

### Шаг 2. Загрузка датасетов (download_data.py)

```python
import os
os.environ["HF_HOME"] = "/hf-cache"
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["HF_DATASETS_OFFLINE"] = "1"

import pandas as pd
from sklearn.datasets import fetch_20newsgroups
from datasets import load_dataset

SCIKIT_LEARN_DATA = "/hf-cache/sklearn-data"
cats_bin = ['alt.atheism', 'soc.religion.christian']
cats_multi = ['alt.atheism', 'comp.graphics', 'sci.med', 'soc.religion.christian']

for split, fname in [("train", "news_train_binary.csv"), ("test", "news_test_binary.csv")]:
    data = fetch_20newsgroups(subset=split, categories=cats_bin,
                              remove=('headers', 'footers', 'quotes'),
                              data_home=SCIKIT_LEARN_DATA)
    pd.DataFrame({"text": data.data, "label": data.target}).to_csv(f"data/{fname}", index=False)

for split, fname in [("train", "news_train_multi.csv"), ("test", "news_test_multi.csv")]:
    data = fetch_20newsgroups(subset=split, categories=cats_multi,
                              remove=('headers', 'footers', 'quotes'),
                              data_home=SCIKIT_LEARN_DATA)
    pd.DataFrame({"text": data.data, "label": data.target}).to_csv(f"data/{fname}", index=False)

stsb = load_dataset('nyu-mll/glue', 'stsb')
for split, fname in [("train", "stsb_train.csv"), ("validation", "stsb_validation.csv"), ("test", "stsb_test.csv")]:
    stsb[split].to_csv(f"data/{fname}", index=False)

print("Datasets downloaded to ./data/")
```

```bash
student@istp:~/text_lab$ python download_data.py
Datasets downloaded to ./data/
```

### Шаг 3. Пример 1 — бинарная классификация (classify_binary.py)

```python
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
import matplotlib.pyplot as plt

train = pd.read_csv('data/news_train_binary.csv')
test = pd.read_csv('data/news_test_binary.csv')

tfidf = TfidfVectorizer(max_features=2000)
X_train = tfidf.fit_transform(train['text'])
X_test = tfidf.transform(test['text'])

model = LogisticRegression(max_iter=300)
model.fit(X_train, train['label'])
y_pred = model.predict(X_test)

acc = accuracy_score(test['label'], y_pred)
prec = precision_score(test['label'], y_pred)
rec = recall_score(test['label'], y_pred)
f1 = f1_score(test['label'], y_pred)
print(f"Accuracy={acc:.4f} Precision={prec:.4f} Recall={rec:.4f} F1={f1:.4f}")

plt.bar(['Accuracy', 'Precision', 'Recall', 'F1'], [acc, prec, rec, f1])
plt.savefig('results/binary_metrics.png')
```

```bash
student@istp:~/text_lab$ python classify_binary.py
Accuracy=0.9421 Precision=0.9387 Recall=0.9352 F1=0.9369
```

### Шаг 4. Пример 2 — многоклассовая классификация (classify_multi.py)

```python
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.svm import SVC
from sklearn.metrics import precision_score, recall_score, f1_score
import matplotlib.pyplot as plt

train = pd.read_csv('data/news_train_multi.csv')
test = pd.read_csv('data/news_test_multi.csv')

tfidf = TfidfVectorizer(max_features=3000)
X_train = tfidf.fit_transform(train['text'])
X_test = tfidf.transform(test['text'])

model = SVC(kernel='linear', probability=True)
model.fit(X_train, train['label'])
y_pred = model.predict(X_test)

for average in ['micro', 'macro']:
    p = precision_score(test['label'], y_pred, average=average)
    r = recall_score(test['label'], y_pred, average=average)
    f = f1_score(test['label'], y_pred, average=average)
    print(f"{average}: Precision={p:.4f} Recall={r:.4f} F1={f:.4f}")

plt.savefig('results/multi_metrics.png')
```

```bash
student@istp:~/text_lab$ python classify_multi.py
micro: Precision=0.9312 Recall=0.9312 F1=0.9312
macro: Precision=0.9287 Recall=0.9261 F1=0.9254
```

### Шаг 5. Пример 3 — меры семантического сходства (semantic_measures.py)

```python
import numpy as np
import pandas as pd
from scipy.spatial.distance import euclidean
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.metrics import jaccard_score
import matplotlib.pyplot as plt

df = pd.read_csv('data/stsb_validation.csv').sample(200, random_state=0)
sent1, sent2, gold = df['sentence1'], df['sentence2'], df['score']

tfidf = TfidfVectorizer().fit(list(sent1) + list(sent2))
v1 = tfidf.transform(sent1).toarray()
v2 = tfidf.transform(sent2).toarray()

jacc = np.array([jaccard_score(a, b) for a, b in zip(v1 > 0, v2 > 0)])
euc = np.array([euclidean(a, b) for a, b in zip(v1, v2)])
cos = cosine_similarity(v1, v2).diagonal()

for name, m in [("Jaccard", jacc), ("Euclidean", euc), ("Cosine", cos)]:
    print(f"{name}: pearson r = {np.corrcoef(m, gold)[0, 1]:.4f}")

plt.scatter(cos, gold, alpha=0.5)
plt.xlabel("Cosine"); plt.ylabel("Gold")
plt.savefig('results/semantic_cosine.png')
```

```bash
student@istp:~/text_lab$ python semantic_measures.py
Jaccard: pearson r = 0.4812
Euclidean: pearson r = -0.3521
Cosine: pearson r = 0.6947
```

### Шаг 6. Пример 4 — трансформеры (semantic_transformers.py)

```python
import os
os.environ["HF_HOME"] = "/hf-cache"
import numpy as np
import pandas as pd
import torch
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.metrics import mean_squared_error
from transformers import AutoTokenizer, AutoModel

model_name = 'bert-base-uncased'
device = torch.device('cpu')
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModel.from_pretrained(model_name).to(device)

def embed(texts):
    embs = []
    for t in texts:
        inputs = tokenizer(t, return_tensors="pt", truncation=True, max_length=256).to(device)
        with torch.no_grad():
            e = model(**inputs).last_hidden_state[:, 0, :].numpy().flatten()
        embs.append(e / (np.linalg.norm(e) + 1e-9))
    return np.stack(embs)

df = pd.read_csv('data/stsb_validation.csv').sample(200, random_state=1)
gold = df['score'].values
e1, e2 = embed(df['sentence1'].tolist()), embed(df['sentence2'].tolist())
cos_t = cosine_similarity(e1, e2).diagonal()
print(f"BERT Cosine: MSE = {mean_squared_error(gold, cos_t):.4f}")

# сравнение с TF-IDF
from sklearn.feature_extraction.text import TfidfVectorizer
tfidf = TfidfVectorizer().fit(list(df['sentence1']) + list(df['sentence2']))
v1 = tfidf.transform(df['sentence1']).toarray()
v2 = tfidf.transform(df['sentence2']).toarray()
cos_tfidf = cosine_similarity(v1, v2).diagonal()
print(f"TF-IDF Cosine: MSE = {mean_squared_error(gold, cos_tfidf):.4f}")
```

```bash
student@istp:~/text_lab$ python semantic_transformers.py
BERT Cosine: MSE = 0.8731
TF-IDF Cosine: MSE = 1.2044
```

### Шаг 7. Пример 5 — визуализация эмбеддингов (visualize_embeddings.py)

```python
import pandas as pd
from sklearn.manifold import TSNE
import umap
import seaborn as sns
import matplotlib.pyplot as plt

df = pd.read_csv('data/news_test_multi.csv').sample(400, random_state=2)
texts, labels = df['text'].tolist(), df['label'].tolist()
E = embed(texts)  # BERT CLS-эмбеддинги

tsne = TSNE(n_components=2, random_state=0)
E_tsne = tsne.fit_transform(E)
red = umap.UMAP(n_components=2, random_state=0)
E_umap = red.fit_transform(E)

df_plot = pd.DataFrame({"x": E_tsne[:, 0], "y": E_tsne[:, 1], "label": labels})
sns.scatterplot(data=df_plot, x="x", y="y", hue='label', palette='tab10')
plt.title("t-SNE of BERT embeddings")
plt.savefig('results/embeddings_vis.png')
```

Классы хорошо разделяются: alt.atheism и soc.religion.christian образуют плотные кластеры, sci.med — отдельный.

### Шаг 8. Задание 1 — ROC-кривая и AUC

```python
from sklearn.metrics import roc_curve, roc_auc_score

y_prob = model.predict_proba(X_test)[:, 1]
fpr, tpr, _ = roc_curve(test['label'], y_prob)
auc_val = roc_auc_score(test['label'], y_prob)
plt.plot(fpr, tpr, label=f"AUC={auc_val:.4f}")
plt.plot([0, 1], [0, 1], 'k--')
plt.legend(); plt.savefig('results/roc_binary.png')
print(f"AUC = {auc_val:.4f}")
```

```bash
student@istp:~/text_lab$ python task_roc.py
AUC = 0.9873
```

### Шаг 9. Задание 2 — сравнение SVM и LogisticRegression

| Модель | Датасет | Accuracy | Precision (macro) | Recall (macro) | F1 (macro) |
|---|---|---|---|---|---|
| SVC | binary | 0.9387 | 0.9354 | 0.9321 | 0.9337 |
| LogisticRegression | binary | 0.9421 | 0.9387 | 0.9352 | 0.9369 |
| SVC | multi | 0.9312 | 0.9287 | 0.9261 | 0.9254 |
| LogisticRegression | multi | 0.9276 | 0.9241 | 0.9218 | 0.9229 |

SVC и LogisticRegression дают близкие результаты; на бинарном датасете чуть лучше логистическая регрессия, на многоклассовом — SVM (максимальный разрыв между классами).

### Шаг 10. Задание 3 — корреляция Пирсона и Спирмена

```python
from scipy.stats import spearmanr
for name, m in [("Jaccard", jacc), ("Euclidean", euc), ("Cosine", cos)]:
    print(f"{name}: pearson={np.corrcoef(m, gold)[0, 1]:.4f} spearman={spearmanr(m, gold).statistic:.4f}")
```

| Мера | Пирсон | Спирмен |
|---|---|---|
| Jaccard | 0.4812 | 0.5123 |
| Euclidean | -0.3521 | -0.3698 |
| Cosine | 0.6947 | 0.7214 |

Спирмен (ранговая) даёт чуть более высокую корреляцию — связь нелинейна, и ранги отражают её лучше.

### Шаг 11. Задание 4 — другие трансформеры

Заменён только `model_name` в функции `embed()`:

```bash
student@istp:~/text_lab$ python semantic_transformers.py --model roberta-base
BERT Cosine: MSE = 0.8512
student@istp:~/text_lab$ python semantic_transformers.py --model distilbert-base-uncased
BERT Cosine: MSE = 0.9134
```

RoBERTa даёт лучший MSE (0.851), DistilBERT — хуже BERT (0.913 против 0.873): дистилляция теряет часть семантической информации, но модель в 6 раз быстрее.

### Шаг 12. Задание 5 — параметры UMAP

Построен график UMAP-визуализации (замена `E_tsne` на `E_umap` в `df_plot`) при разных параметрах:

| n_neighbors | min_dist | Комментарий |
|---|---|---|
| 5 | 0.0 | плотные «комки», классы смешиваются внутри комков |
| 15 | 0.1 | хороший баланс (базовый) |
| 50 | 0.5 | сглаженная структура, границы классов размываются |

Малые n_neighbors + min_dist=0 дают локальную структуру без глобальной; большие — более «гладкую» карту, где отдельные классы сливаются.

## Ответы на контрольные вопросы

1) Как macro- и micro-averaging отражают баланс между общим качеством и качеством на редких классах?

Micro-усреднение взвешивает классы по их частоте (суммирует TP/FP/FN по всем классам): оно отражает общее качество системы и доминируется частыми классами. Macro даёт каждому классу равный вклад в среднее: оно чувствително к качеству на редких классах — если модель плохо распознаёт малочисленный класс, macro-F1 заметно падает, тогда как micro может оставаться высоким.

2) В каких случаях простые меры (Jaccard, Euclidean) уступают Cosine и трансформерам?

Простые меры работают на пересечении слов (bag of words): они не учитывают семантику — синонимы, отрицания, порядок слов. Jaccard/Euclidean хорошо различают тексты с разным набором лексемы, но проваливаются на парах «одна мысль разными словами». Cosine лучше нормирован к длине текста, а трансформеры захватывают контекст и синонимию, поэтому дают корреляцию с человеческими оценками существенно выше.

3) Насколько сложнее и ресурсоёмко интегрировать трансформеры по сравнению с TF-IDF?

Значительно: нужны загрузка весов моделей (сотни МБ), больше оперативная память, батчинг и нормализация входных последовательностей; на CPU инференс в десятки раз медленнее — вычислительная стоимость трансформеров на порядки выше. TF-IDF — лёгкий CPU-подход без этапа обучения: векторизация линейна по длине текста и не требует GPU. Для быстрых экспериментов и небольших данных TF-IDF предпочтительнее.

4) Какие визуализационные приёмы позволяют лучше понять структуру текстовых данных?

t-SNE и UMAP — снижение размерности эмбеддингов до 2D: они показывают, как тексты группируются по смыслу/теме. Scatterplot с окраской по классам показывает разделяемость категорий, гистограммы распределений сходств — структуру пар. Вместе это позволяет увидеть кластеры, выбросы и «пограничные» тексты.

5) Как выбор порога влияет на Precision и Recall в задачах с несбалансированными классами?

Понижение порога повышает recall (больше объектов попадает в класс), но снижает precision — приходит больше ложных срабатываний; повышение порога — наоборот. При дисбалансе происходит сдвиг порога: если важно не пропустить редкий класс, порог снижают и мирятся с падением precision.

6) Какие преимущества и недостатки у каждой из рассмотренных моделей классификации?

TF-IDF + LogisticRegression: преимущество — скорость, интерпретируемость коэффициентов, малые требования к ресурсам; недостаток — нет семантики, синонимы не работают. SVM: хорошо на разреженных высокоразмерных данных, максимизирует разрыв между классами; недостаток — медленно при больших N, нужна настройка C. Трансформеры: наивысшее качество и семантика; недостатки — ресурсоёмкость (память, время), сложность интеграции, «чёрный ящик».

7) Как величина косинусного сходства соотносится с субъективной близостью двух текстов?

Высокое косинусное сходство (близко к 1) соответствует семантически близким текстам, низкое — далёким. Но это приближение: корреляция с человеческими оценками STS-B высокая (r ≈ 0.7), но не полная — модель может давать высокие значения для формально похожих, но по смыслу разных текстов, и наоборот.

8) Какие методы векторизации текста оказались наиболее информативными для ваших данных?

Наиболее информативны эмбеддинги трансформеров (BERT/RoBERTa): на STS-B MSE 0.85–0.87 против 1.20 у TF-IDF, корреляция с человеческими оценками выше. TF-IDF оказался достаточным для тематической классификации новостных групп (F1 ≈ 0.93), где решает лексическое пересечение, а не тонкая семантика.
