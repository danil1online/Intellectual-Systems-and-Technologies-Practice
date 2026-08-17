# Методические указания к лабораторной работе №3 
**Тема:** Метрики оценки качества решения задач поддержки принятия решений, регрессии и эвристической оптимизации. 2 часа

---

## 🎯 Цель работы  
Изучить ключевые метрики для оценки качества решений в следующих областях:
- кластеризация
- регрессия
- оптимизация

В задачу классификации также можно формализовать множество практических задач принятия решений, однако, ее метрики были рассмотрены неоднократно в рамках предыдущих работ и в данной рассматриваться не будут.

---

## 📌 Задачи  
- Ознакомиться с разновидностями метрик качества для кластеризации, регрессии и оптимизации.
- На практических примерах реализовать вычисление и визуализацию этих метрик.
- Проанализировать полученные результаты и обосновать выбор конкретных метрик для разных задач.

---

## 📁 Материалы и методы
- Язык программирования – Python 3.10.
- Основные библиотеки:
  - [matplotlib](https://matplotlib.org/),
  - [scikit-learn](https://scikit-learn.org/),
  - [numpy](https://numpy.org/)
- Датасеты:
  - Для кластеризации – [Iris (scikit-learn)](https://scikit-learn.org/1.5/auto_examples/datasets/plot_iris_dataset.html)
  - Для регрессии – [Diabetes (scikit-learn)](https://scikit-learn.org/stable/modules/generated/sklearn.datasets.load_diabetes.html)
  - Для оптимизации – синтетическая функция (сфера или функция Растригина)
---

## 📚 Краткая теоретическая информация  

### 📚 Введение: связь с системами поддержки принятия решений

Системы поддержки принятия решений — программные средства, которые помогают специалистам обрабатывать данные, строить прогнозы, выявлять скрытые закономерности и выбирать оптимальные варианты действий.

  - Кластеризация в СППР применяется для сегментации клиентов, выявления аномалий и создания рекомендаций.
  - Регрессия — для прогнозирования ключевых показателей (продаж, спроса, рисков).
  - Оптимизация — для подбора конфигураций, планирования и многокритериального выбора альтернатив.

1. 📚 Кластеризация в СППР
  - Задача: группировка объектов без заранее заданных меток для поддержки анализа и сегментации.
  - Метрики:
    - [Silhouette Score](https://wiki.loginom.ru/articles/cluster-silhouette-index.html): мера однородности внутри кластеров и различимости между ними,
    - [Calinski–Harabasz Index](https://permetrics.readthedocs.io/en/latest/pages/clustering/CHI.html): отношение межкластерного разброса к внутрикластерному,
    - [Davies–Bouldin Index](https://github.com/akankshadara/Davies_Bouldin_Index_KMeans): средняя похожесть каждого кластера с «наиболее похожим» другим (меньше – лучше)
2. 📚 Регрессия в СППР
  - Задача: непрерывное прогнозирование для оценки и планирования.
  - Метрики:
    - [MAE Mean Absolute Error](https://wiki.loginom.ru/articles/mae.html),
    - [MSE Mean Squared Error](https://habr.com/ru/articles/821547/),
    - [R² коэффициент детерминации](https://habr.com/ru/articles/821547/).
3. Оптимизация в СППР
3.1. Однокритериальная оптимизация
  - Best‐found solution Значение целевой функции
  - Скорость сходимости (число итераций / шагов до достижения порога)
  - Время выполнения
3.2. [Многокритериальная оптимизация](https://neerc.ifmo.ru/wiki/index.php?title=Задача_многокритериальной_оптимизации._Multiobjectivization)
  - Определение: одновременный учёт двух и более целей (например, стоимость vs. надёжность).
  - Парето-эффективность: решение считается Парето-оптимальным, если нельзя улучшить одну цель, не ухудшив другую.
  - Парето-фронт: набор всех Парето-оптимальных решений.
  - [Метрики оценки фронта Парето](https://cyberleninka.ru/article/n/programmnaya-sistema-pareto-rating-dlya-otsenki-kachestva-pareto-approksimatsii-v-zadache-mnogokriterialnoy-optimizatsii/viewer)
    - Hypervolume (объём гиперпрямоугольника, захватываемого фронтом)
    - Generational Distance (среднее расстояние до истинного фронта)
    - Spread / Spacing (равномерность распределения точек фронта)
    - Epsilon-индикатор (минимальное смещение фронта для покрытия эталонного)

---
 
## ⚙️ Настройка среды

0. Подключитесь к [Jupyter-Hub-ИИСТ-НПИ](http://89.110.116.79:7998/) из [первой работы](docs/lab_1_cv_metrics.md#%EF%B8%8F-настройка-среды)
1. Создайте в корне домашнего каталога каталог проекта и перейдите в него:
```bash

mkdir lab_metrics && cd lab_metrics
mkdir results

```
2. Создайте и активируйте виртуальное окружение:
```bash

python3.10 -m venv venv
source venv/bin/activate

```

3. Установите зависимости:
```bash

pip install --upgrade pip setuptools wheel
pip install scikit-learn matplotlib numpy

```

---

## 🧪 Примеры

### 🧪 Пример 1. Кластеризация и метрики качества

```python
#!/usr/bin/env python3
# file: clustering.py

from sklearn.datasets import load_iris
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score, calinski_harabasz_score, davies_bouldin_score
from sklearn.decomposition import PCA
import matplotlib.pyplot as plt

# Загрузка и подготовка данных
data = load_iris()
X = data.data

# Кластеризация
n_clusters = 3
model = KMeans(n_clusters=n_clusters, random_state=42)
labels = model.fit_predict(X)

# Расчёт метрик
sil_score = silhouette_score(X, labels)
ch_score = calinski_harabasz_score(X, labels)
db_score = davies_bouldin_score(X, labels)

print(f"Silhouette Score: {sil_score:.3f}")
print(f"Calinski–Harabasz Index: {ch_score:.3f}")
print(f"Davies–Bouldin Index: {db_score:.3f}")

# Визуализация кластеров в 2D через PCA
pca = PCA(n_components=2)
X2 = pca.fit_transform(X)
plt.scatter(X2[:,0], X2[:,1], c=labels, cmap='tab10', alpha=0.7)
plt.title("KMeans Clustering (Iris)")
plt.xlabel("PC1")
plt.ylabel("PC2")
plt.savefig("results/clustering_iris.png")
print("График сохранён в results/clustering_iris.png")
```


Запуск из командной строки:

```bash
python clustering.py
```

### 🧪 Пример 2. Регрессия и метрики

```python

#!/usr/bin/env python3
# file: regression.py

from sklearn.datasets import load_diabetes
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import matplotlib.pyplot as plt

data = load_diabetes()
X, y = data.data, data.target

model = LinearRegression()
model.fit(X, y)
y_pred = model.predict(X)

mae = mean_absolute_error(y, y_pred)
mse = mean_squared_error(y, y_pred)
r2 = r2_score(y, y_pred)

print(f"MAE: {mae:.2f}, MSE: {mse:.2f}, R²: {r2:.3f}")

plt.scatter(y, y_pred, alpha=0.5)
plt.xlabel("Actual")
plt.ylabel("Predicted")
plt.title("Regression: Actual vs Predicted")
plt.savefig("results/regression_scatter.png")
print("График сохранён в results/regression_scatter.png")
```

Запуск:

```bash

python regression.py

```

### 🧪 Пример 3. Оптимизация. Исследуемая область - сфера

```python

#!/usr/bin/env python3
# file: optimization.py

import numpy as np
import matplotlib.pyplot as plt

def sphere(x):
    return np.sum(x**2)

def random_search(dim, iterations):
    best = float('inf')
    history = []
    for i in range(iterations):
        candidate = np.random.uniform(-5, 5, size=dim)
        value = sphere(candidate)
        if value < best:
            best = value
        history.append(best)
    return history

history = random_search(dim=10, iterations=200)
plt.plot(history)
plt.xlabel("Iteration")
plt.ylabel("Best Value")
plt.title("Random Search Convergence")
plt.savefig("results/optimization_convergence.png")
print("График сохранён в results/optimization_convergence.png")
```

Запуск:

```bash

python optimization.py

```

### 🧪 Пример 4. Оптимизация. bi-objective случайный поиск с визуализацией фронта Парето

```python

#!/usr/bin/env python3
# file: bi_objective_optimization.py

import numpy as np
import matplotlib.pyplot as plt
from itertools import product

def f1(x):
    return np.sum(x**2)

def f2(x):
    return np.sum((x-2)**2)

def is_pareto(points):
    pareto = []
    for i, p in enumerate(points):
        dominated = False
        for j, q in enumerate(points):
            if all(q <= p) and any(q < p):
                dominated = True
                break
        if not dominated:
            pareto.append(p)
    return np.array(pareto)

def random_search(dim, iterations):
    results = []
    for _ in range(iterations):
        x = np.random.uniform(-5, 5, size=dim)
        results.append([f1(x), f2(x)])
    return np.array(results)

# Основной запуск
history = random_search(dim=2, iterations=500)
front = is_pareto(history)

# Визуализация
plt.scatter(history[:,0], history[:,1], alpha=0.3, label='All solutions')
plt.scatter(front[:,0], front[:,1], color='red', label='Pareto front')
plt.xlabel("f1(x) = ∑x²")
plt.ylabel("f2(x) = ∑(x–2)²")
plt.title("Bi-objective Random Search and Pareto Front")
plt.legend()
plt.savefig("results/bi_objective_pareto.png")
print("График сохранён в results/bi_objective_pareto.png")
```

Запуск:

```bash

python bi_objective_optimization.py

```

### 🧪 Пример 5. Оптимизация функции Растригина

```python

#!/usr/bin/env python3
# file: rastrigin_optimization.py

import numpy as np
import matplotlib.pyplot as plt

def rastrigin(x, A=10):
    """
    Rastrigin function:
      f(x) = A * n + sum(x_i^2 - A * cos(2π x_i))
    Global minimum at x = 0, f(0) = 0.
    """
    return A * len(x) + np.sum(x**2 - A * np.cos(2 * np.pi * x))

def random_search(dim, iterations, bounds):
    best = float('inf')
    history = []
    for i in range(iterations):
        candidate = np.random.uniform(bounds[0], bounds[1], size=dim)
        value = rastrigin(candidate)
        if value < best:
            best = value
        history.append(best)
    return history

if __name__ == "__main__":
    # Параметры поиска
    dim = 2
    iterations = 1000
    bounds = (-5.12, 5.12)

    # Запуск случайного поиска
    history = random_search(dim, iterations, bounds)

    # Визуализация сходимости
    plt.figure(figsize=(6,4))
    plt.plot(history, color='blue', linewidth=1)
    plt.xlabel("Итерация")
    plt.ylabel("Лучшее значение f(x)")
    plt.title("Конвергенция случайного поиска на функции Растригина")
    plt.grid(True)
    plt.tight_layout()
    plt.savefig("results/rastrigin_convergence.png")
    print("График конвергенции сохранён в results/rastrigin_convergence.png")
```

Запуск:

```bash

python rastrigin_optimization.py

```

---
## 📌 Задания для самостоятельной работы

1. 📌 Задание 1. Реализовать задачу кластеризации на датасете Wine (scikit-learn) с расчётом silhouette score, Calinski–Harabasz и Davies–Bouldin.
  - Заготовка кода:
```python
from sklearn.datasets import load_wine
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score, calinski_harabasz_score, davies_bouldin_score
from sklearn.decomposition import PCA
import matplotlib.pyplot as plt

# 1. Загрузить данные
# 2. Применить KMeans (n_clusters=3)
# 3. Рассчитать silhouette_score, calinski_harabasz_score, davies_bouldin_score
# 4. Визуализировать результат через PCA и сохранить в results/
```
2. 📌 Задание 2.

  - Реализовать многокритериальную оптимизацию для трёх целей:

$$
  f_1(x) = \sum x_i^2
$$

$$
  f_2(x) = \sum (x_i-2)^2
$$

$$
  f_3(x) = \sum |x_i+1|
$$

  - Найти и визуализировать трёхмерный Парето-фронт (проецируйте на 2D-сечения).
  - Рассчитать Hypervolume и Spread.

---

## 💡 Не забудьте выключить текущую среду выполнения программы python (должна пропасть надпись (venv) в начале командной строки):

```bash

deactivate

```


## Вопросы
1. Какие метрики были применены в задачах кластеризации, регрессии и оптимизации?
2. В чём принципиальная разница между метриками кластеризации и метриками регрессии?
3. Как выбор числа кластеров влияет на silhouette score и другие индексы?
4. Что важнее в задаче оптимизации: скорость сходимости или точность найденного решения? Почему?
5. Какие ограничения и преимущества есть у эвристических методов по сравнению с аналитическими?
6. Как кластеризация, регрессия и оптимизация интегрируются в СППР?
7. В чём преимущества использования многокритериальных оптимизаций в СППР?
8. Как метрики Парето-фронта помогают выбирать оптимальные решения в условиях конфликтующих целей?
9. Какие кардинальные отличия в выборе метрик при однокритериальной и многокритериальной оптимизации?
10. Какие сценарии применения многокритериальной оптимизации в бизнес-процессах вы можете предложить?
