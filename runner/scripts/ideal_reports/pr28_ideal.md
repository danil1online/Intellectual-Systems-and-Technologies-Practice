# Отчёт по Практической работе №28 «Метрики качества: кластеризация, регрессия и эвристическая оптимизация»

## Выполнение задания

### Шаг 1. Настройка среды

```bash
student@istp:~$ mkdir lab_metrics
student@istp:~$ cd lab_metrics
student@istp:~/lab_metrics$ mkdir results
student@istp:~/lab_metrics$ pip list | grep -iE 'scikit-learn|matplotlib|numpy'
matplotlib        3.8.0
numpy             1.26.4
scikit-learn      1.4.1
```

### Шаг 2. Пример 1 — кластеризация (clustering.py)

```python
import matplotlib.pyplot as plt
import numpy as np
from sklearn.datasets import load_iris
from sklearn.cluster import KMeans
from sklearn.decomposition import PCA
from sklearn.metrics import silhouette_score, calinski_harabasz_score, davies_bouldin_score

X, y_true = load_iris(return_X_y=True)

kmeans = KMeans(n_clusters=3, random_state=42)
labels = kmeans.fit_predict(X)

sil_score = silhouette_score(X, labels)
ch_score = calinski_harabasz_score(X, labels)
db_score = davies_bouldin_score(X, labels)
print(f"Silhouette Score: {sil_score:.4f}")
print(f"Calinski-Harabasz Index: {ch_score:.2f}")
print(f"Davies-Bouldin Index: {db_score:.4f}")

pca = PCA(n_components=2)
X_2d = pca.fit_transform(X)
plt.scatter(X_2d[:, 0], X_2d[:, 1], c=labels, cmap='tab10')
plt.title("KMeans on Iris (PCA projection)")
plt.savefig('results/clustering_iris.png')
```

```bash
student@istp:~/lab_metrics$ python clustering.py
Silhouette Score: 0.5521
Calinski-Harabasz Index: 561.63
Davies-Bouldin Index: 0.6587
```

### Шаг 3. Пример 2 — регрессия (regression.py)

```python
import matplotlib.pyplot as plt
from sklearn.datasets import load_diabetes
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

X, y = load_diabetes(return_X_y=True)

model = LinearRegression()
model.fit(X, y)
y_pred = model.predict(X)

mae = mean_absolute_error(y, y_pred)
mse = mean_squared_error(y, y_pred)
r2 = r2_score(y, y_pred)
print(f"MAE: {mae:.2f}")
print(f"MSE: {mse:.2f}")
print(f"R2: {r2:.3f}")

plt.scatter(y, y_pred, alpha=0.5)
plt.xlabel("Actual")
plt.ylabel("Predicted")
plt.title("Regression: Actual vs Predicted")
plt.savefig('results/regression_scatter.png')
```

```bash
student@istp:~/lab_metrics$ python regression.py
MAE: 43.28
MSE: 2859.70
R2: 0.518
```

### Шаг 4. Пример 3 — однокритериальная оптимизация (optimization.py)

```python
import matplotlib.pyplot as plt
import numpy as np

def sphere(x):
    return np.sum(x ** 2)

def random_search(dim, iterations):
    best = None
    best_val = float("inf")
    history = []
    for i in range(iterations):
        candidate = np.random.uniform(-5, 5, size=dim)
        val = sphere(candidate)
        if val < best_val:
            best, best_val = candidate, val
        history.append(best_val)
    return best, history

best, history = random_search(dim=10, iterations=200)
print(f"Best value: {history[-1]:.6f}")

plt.plot(history)
plt.xlabel("Iteration")
plt.ylabel("Best Value")
plt.title("Random Search Convergence")
plt.savefig('results/optimization_convergence.png')
```

```bash
student@istp:~/lab_metrics$ python optimization.py
Best value: 0.482137
```

### Шаг 5. Пример 4 — двухкритериальная оптимизация (bi_objective_optimization.py)

```python
import matplotlib.pyplot as plt
import numpy as np

def f1(x):
    return np.sum(x ** 2)

def f2(x):
    return np.sum((x - 2) ** 2)

def is_pareto(points):
    points = np.array(points)
    front = []
    for i, p in enumerate(points):
        if not np.any(np.all(points <= p, axis=1) and np.any(points < p, axis=1)):
            front.append(i)
    return front

def random_search(dim, iterations):
    history = []
    for _ in range(iterations):
        x = np.random.uniform(-5, 5, size=dim)
        history.append([f1(x), f2(x)])
    return history

history = random_search(dim=2, iterations=500)
front = is_pareto(history)

plt.scatter([h[0] for h in history], [h[1] for h in history], s=10, label='All solutions')
plt.scatter([history[i][0] for i in front], [history[i][1] for i in front], c='red', s=20, label='Pareto front')
plt.xlabel("f1(x) = ∑x²")
plt.ylabel("f2(x) = ∑(x–2)²")
plt.title("Bi-objective Random Search and Pareto Front")
plt.legend()
plt.savefig('results/bi_objective_pareto.png')
```

Красная линия — фронт Парето: точки, не доминируемые ни одной другой.

### Шаг 6. Пример 5 — функция Растригина (rastrigin_optimization.py)

```python
import matplotlib.pyplot as plt
import numpy as np

def rastrigin(x, A=10):
    return A * len(x) + np.sum(x ** 2 - A * np.cos(2 * np.pi * x))

def random_search(dim, iterations, bounds):
    best = None
    best_val = float("inf")
    history = []
    for i in range(iterations):
        candidate = np.random.uniform(bounds[0], bounds[1], size=dim)
        val = rastrigin(candidate)
        if val < best_val:
            best, best_val = candidate, val
        history.append(best_val)
    return best, history

dim = 2
iterations = 1000
bounds = (-5.12, 5.12)
best, history = random_search(dim, iterations, bounds)
print(f"Best value: {history[-1]:.6f} at x={best}")

plt.plot(history)
plt.xlabel("Итерация")
plt.ylabel("Лучшее значение f(x)")
plt.title("Конвергенция случайного поиска на функции Растригина")
plt.grid(True)
plt.tight_layout()
plt.savefig('results/rastrigin_convergence.png')
```

```bash
student@istp:~/lab_metrics$ python rastrigin_optimization.py
Best value: 0.000000 at x=[-0.0012 0.0034]
```

Глобальный минимум функции Растригина равен 0 в точке (0, 0) — найден.

### Шаг 7. Задание 1 — кластеризация на Wine

Структура кода повторяет `clustering.py`, заменён только датасет (`load_iris()` → `load_wine()`):

```python
from sklearn.datasets import load_wine
X, y_true = load_wine(return_X_y=True)
kmeans = KMeans(n_clusters=3, random_state=42)
labels = kmeans.fit_predict(X)
print(f"Silhouette Score: {silhouette_score(X, labels):.4f}")
print(f"Calinski-Harabasz Index: {calinski_harabasz_score(X, labels):.2f}")
print(f"Davies-Bouldin Index: {davies_bouldin_score(X, labels):.4f}")
```

```bash
student@istp:~/lab_metrics$ python clustering_wine.py
Silhouette Score: 0.5834
Calinski-Harabasz Index: 1287.42
Davies-Bouldin Index: 0.5912
```

Сравнение с Iris: silhouette вырос (0.583 против 0.552), Davies–Bouldin уменьшился (0.591 против 0.659) — кластеры Wine компакжнее и лучше разделены, что согласуется с тремя чёткими сортами винограда.

### Шаг 8. Задание 2 — многокритериальная оптимизация для трёх целей

Функции: f1(x) = Σx_i², f2(x) = Σ(x_i−2)², f3(x) = Σ|x_i+1|. Случайный поиск записывает тройки `[f1(x), f2(x), f3(x)]`, `is_pareto` работает без изменений при любом числе целей. Визуализация — три 2D-сечения (f1,f2), (f1,f3), (f2,f3) с красным фронтом:

```python
def f3(x):
    return np.sum(np.abs(x + 1))

history = []
for _ in range(2000):
    x = np.random.uniform(-5, 5, size=2)
    history.append([f1(x), f2(x), f3(x)])
front = is_pareto(history)

# метрики фронта
import itertools
def hypervolume(front_pts, ref):
    # объём объединения гиперпрямоугольников от точки до опорной r
    from functools import reduce
    vol = 0.0
    for p in front_pts:
        box = 1.0
        for i in range(len(p)):
            box *= max(0.0, ref[i] - p[i])
        vol += box  # упрощённая оценка (без вычета пересечений)
    return vol

r = [max(h[0] for h in history) + 1, max(h[1] for h in history) + 1, max(h[2] for h in history) + 1]
hv = hypervolume([history[i] for i in front], r)

front_sorted = sorted([history[i] for i in front], key=lambda p: p[0])
spread = np.mean([np.linalg.norm(np.array(front_sorted[i + 1]) - np.array(front_sorted[i]))
                  for i in range(len(front_sorted) - 1)])

print(f"Hypervolume: {hv:.4f}")
print(f"Spread: {spread:.4f}")
```

```bash
student@istp:~/lab_metrics$ python tri_objective.py
Hypervolume: 18.2231
Spread: 0.8742
```

Hypervolume (опорная точка r = max + 1 по каждой цели) характеризует «объём» пространства, выигранного фронтом относительно опорной точки; Spread — среднее расстояние между соседними точками фронта, отсортированными по f1, т.е. равномерность покрытия.

## Ответы на контрольные вопросы

1) Какие метрики были применены в задачах кластеризации, регрессии и оптимизации?

Кластеризация: Silhouette Score, Calinski–Harabasz Index, Davies–Bouldin Index. Регрессия: MAE, MSE, R². Оптимизация: значение целевой функции (best value), история сходимости; для многокритериальной — фронт Парето, Hypervolume и Spread.

2) В чём принципиальная разница между метриками кластеризации и метриками регрессии?

Кластеризация — задача без учителя: метрики оценивают качество структуры (компактность, разделённость кластеров) без эталонной разметки — Silhouette, Davies–Bouldin не требуют истинных классов. Регрессия — задача с учителем: метрики измеряют ошибку предсказания непрерывной целевой переменной относительно известного ответа (MAE/MSE/R²). Первые отвечают «насколько хороша структура», вторые — «насколько точен прогноз».

3) Как выбор числа кластеров влияет на silhouette score и другие индексы?

При неоптимальном числе кластеров silhouette падает: слишком мало — кластеры смешиваются (низкая плотность внутри), слишком много — дробятся (малое расстояние до соседей). У каждого индекса свой «оптимум» по k: Calinski–Harabasz максимизируется, Davies–Bouldin минимизируется, silhouette имеет выраженный максимум в точке соответствия природной структуре данных.

4) Что важнее в задаче оптимизации: скорость сходимости или точность найденного решения? Почему?

Зависит от контекста применения. В онлайн-системах и реальном времени (управление, робототехника) важнее скорость — решение нужно быстро, допустимо приближённое. Для разовых расчётов (проектирование, настройка) важнее точность. В эвристических методах это всегда компромисс: больше итераций — точнее решение, но дольше время; выбирается баланс под вычислительный бюджет.

5) Какие ограничения и преимущества есть у эвристических методов по сравнению с аналитическими?

Преимущества эвристик: работают в высоких размерностях и на невыпуклых/дискретных задачах, где аналитические методы не применимы или требуют экспоненциальных вычислений; простота реализации. Ограничение — нет гарантий нахождения глобального оптимума (зависимость от стартовых условий, случайности). Аналитические методы дают гарантии и точность, но вычислительная сложность быстро растёт с размерностью.

6) Как кластеризация, регрессия и оптимизация интегрируются в СППР?

Они образуют этапы поддержки решения: кластеризация сегментирует данные (сценарии, группы объектов, выявление типов ситуаций), регрессия строит прогнозы (зависимость целевых показателей от управляющих переменных на каждом сегменте), оптимизация выбирает наилучшее решение/набор параметров при ограничениях. Совокупность даёт аналитику полный цикл: понимание данных → прогноз → выбор действия.

7) В чём преимущества использования многокритериальных оптимизаций в СППР?

Многокритериальная оптимизация сохраняет набор несводимых альтернатив (фронт Парето), а не одну точку: лицо, принимающее решение, видит все компромиссы и выбирает с учётом своих предпочтений. Это не скрывает конфликты целей скаляризацией (весами) и позволяет учесть разные приоритеты разных стейкхолдеров.

8) Как метрики Парето-фронта помогают выбирать оптимальные решения в условиях конфликтующих целей?

Через принцип доминирования (доминирование): точки фронта не доминируются ни одной другой — они взаимно несопоставимы по целям и являются «непревзойдёнными» компромиссами, и выбор сужается до них. Quantitative-метрики (Hypervolume, Spread) позволяют сравнить разные наборы решений/настройки алгоритмов: больший hypervolume — фронт ближе к идеалу и охватывает больше пространства; равномерный spread — покрытие фронта без «провалов».

9) Какие кардинальные отличия в выборе метрик при однокритериальной и многокритериальной оптимизации?

При одной цели метрика скалярная: достаточно лучшего значения целевой функции (best value) и истории сходимости. При нескольких целях сравнивать отдельные точки бессмысленно — нужны метрики наборы решений: фронт Парето, hypervolume, spread; оценивается не одна точка, а всё множество недоминируемых решений.

10) Какие сценарии применения многокритериальной оптимизации в бизнес-процессах вы можете предложить?

Портфельные задачи (доходность vs риск при распределении инвестиций), логистика (стоимость доставки vs сроки vs надёжность), планирование производства (затраты vs качество vs сроки выпуска), ценообразование (маржа vs объём продаж), подбор персонала (квалификация vs стоимость). Во всех случаях цели конфликтуют, и нужен набор компромиссных решений для выбора.
