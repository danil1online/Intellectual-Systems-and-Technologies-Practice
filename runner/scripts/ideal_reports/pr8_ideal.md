--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Импорт библиотек
import random
import numpy as np
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
from sklearn.datasets import make_blobs
%matplotlib inline
import pandas as pd

--- Ячейка кода 3 ---
# Генерация набора случайных данных: 5000 точек, 4 кластера
np.random.seed(0)
X, y = make_blobs(n_samples=5000, centers=[[4,4], [-2, -1], [2, -3], [1, 1]], cluster_std=0.9)
plt.scatter(X[:, 0], X[:, 1], marker='.')
plt.title('Исходные данные')

--- Ячейка кода 4 ---
# Настройка и обучение модели K-Means (4 кластера)
k_means = KMeans(init="k-means++", n_clusters=4, n_init='auto')
k_means.fit(X)

k_means_labels = k_means.labels_
k_means_cluster_centers = k_means.cluster_centers_

fig = plt.figure(figsize=(6, 4))
colors = plt.cm.Spectral(np.linspace(0, 1, len(set(k_means_labels))))
ax = fig.add_subplot(1, 1, 1)
for k, col in zip(range(len(k_means_cluster_centers)), colors):
    mask = (k_means_labels == k)
    ax.scatter(X[mask, 0], X[mask, 1], color=col, marker='o', s=25)
ax.set_title('KMeans')

--- Ячейка кода 5 ---
# Задание 1: те же данные в 3 кластера + init='random' с разными n_init
k_means_3 = KMeans(init="k-means++", n_clusters=3, n_init='auto')
k_means_3.fit(X)
print("n_clusters=3, inertia:", k_means_3.inertia_)

k_means_rand = KMeans(init="random", n_clusters=3, n_init=10)
k_means_rand.fit(X)
print("init='random', n_init=10, inertia:", k_means_rand.inertia_)

--- Ячейка кода 6 ---
# Сегментация клиентов: загрузка данных
cust_df = pd.read_csv("~/data/Cust_Segmentation.csv")
cust_df.head()
[вывод]    CustomerId     Age  Education  ...
0           1      40         12  ...

--- Ячейка кода 7 ---
# Предварительная обработка: убрать Address, нормализовать
df = cust_df.drop('Address', axis=1)
X = df.values[:, 1:]
X = np.nan_to_num(X)
from sklearn.preprocessing import StandardScaler
Clus_dataSet = StandardScaler().fit_transform(X)

--- Ячейка кода 8 ---
# Модель KMeans (3 кластера) на данных клиентов
clusterNum = 3
k_means = KMeans(init="k-means++", n_clusters=clusterNum, n_init=12)
k_means.fit(X)
labels = k_means.labels_
print(labels[:10])

df["Clus_km"] = labels
df.head(5)
df.groupby('Clus_km').mean()
[вывод] [0 1 2 0 1 2 0 1 0 2]

--- Ячейка кода 9 ---
# Анализ модели: scatter Age/Income и 3D-график
area = np.pi * (X[:, 1]) ** 2
plt.scatter(X[:, 0], X[:, 3], s=area, c=labels.astype(float), alpha=0.5)
plt.xlabel('Age', fontsize=18)
plt.ylabel('Income', fontsize=16)

fig = plt.figure(1, figsize=(8, 6))
ax = fig.add_subplot(111, projection='3d')
ax.scatter(X[:, 1], X[:, 0], X[:, 3], c=labels.astype(float))
ax.set_xlabel('Education')
ax.set_ylabel('Age')
ax.set_zlabel('Income')

--- Ячейка Markdown 1 ---
## Задание 2: анализ трёхмерного графика

Основной признак, который отличает кластеры друг от друга — доход (Income): кластер с высоким доходом заметно отделён по вертикальной оси. Возраст и образование различают кластеры слабее; например, два кластера перекрываются по возрасту, но разделены по доходу. Вывод: для сегментации клиентов ключевым является уровень дохода.
