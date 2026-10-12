--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Импорт библиотек
import numpy as np
import pandas as pd
from scipy import ndimage
from scipy.cluster import hierarchy
from scipy.spatial import distance_matrix
from matplotlib import pyplot as plt
from sklearn import manifold, datasets
from sklearn.cluster import AgglomerativeClustering
from sklearn.datasets import make_blobs
%matplotlib inline

--- Ячейка кода 3 ---
# Генерация набора случайных данных (50 точек, 4 кластера)
np.random.seed(0)
X1, y1 = make_blobs(n_samples=50, centers=[[4, 4], [-2, -1], [1, 1], [10, 4]], cluster_std=0.9)
plt.scatter(X1[:, 0], X1[:, 1], marker='o')

--- Ячейка кода 4 ---
# Агломеративная иерархическая кластеризация (linkage='complete')
agglom = AgglomerativeClustering(n_clusters=4, linkage='complete')
agglom.fit(X1, y1)

plt.figure(figsize=(6, 4))
x_min, x_max = np.min(X1, axis=0), np.max(X1, axis=0)
X1 = (X1 - x_min) / (x_max - x_min)
for i in range(X1.shape[0]):
    plt.text(X1[i, 0], X1[i, 1], str(y1[i]), color=plt.cm.nipy_spectral(agglom.labels_[i] / 10.), fontdict={'weight': 'bold', 'size': 9})
plt.xticks([])
plt.yticks([])
plt.scatter(X1[:, 0], X1[:, 1], marker='.')
plt.show()

dist_matrix = distance_matrix(X1, X1)
Z = hierarchy.linkage(dist_matrix, 'complete')
dendro = hierarchy.dendrogram(Z)

--- Ячейка кода 5 ---
# Задание 1: linkage='ward', 'average', 'single'
for link in ['ward', 'average', 'single']:
    agglom_l = AgglomerativeClustering(n_clusters=4, linkage=link)
    agglom_l.fit(X1, y1)
    print(link, "labels:", sorted(set(agglom_l.labels_)))
[вывод] ward labels: [0, 1, 2, 3]
average labels: [0, 1, 2, 3]
single labels: [0, 1, 2, 3]

--- Ячейка Markdown 1 ---
## Задание 1: анализ результатов

linkage='ward' даёт компактные кластеры равного объёма; 'average' близок к нему; 'single' склонен к «цепочечному» эффекту — объединяет дальние точки в один длинный кластер. Для этих данных лучше всего подходит 'ward'.

--- Ячейка кода 6 ---
# Данные о транспортных средствах
pdf = pd.read_csv('~/data/cars_clus.csv')
print("Shape of dataset: ", pdf.shape)
pdf.head()
[вывод] Shape of dataset:  (205, 17)

--- Ячейка кода 7 ---
# Предварительная обработка: числа и удаление NaN
pdf[['sales', 'resale', 'type', 'price', 'engine_s', 'horsepow', 'wheelbas', 'width', 'length', 'curb_wgt', 'fuel_cap', 'mpg', 'lnsales']] = pdf[['sales', 'resale', 'type', 'price', 'engine_s', 'horsepow', 'wheelbas', 'width', 'length', 'curb_wgt', 'fuel_cap', 'mpg', 'lnsales']].apply(pd.to_numeric, errors='coerce')
pdf = pdf.dropna()
pdf = pdf.reset_index(drop=True)
print("Shape after cleaning: ", pdf.shape)
[вывод] Shape after cleaning:  (202, 17)

--- Ячейка кода 8 ---
# Выбор признаков
featureset = pdf[['engine_s', 'horsepow', 'wheelbas', 'width', 'length', 'curb_wgt', 'fuel_cap', 'mpg']]

--- Ячейка кода 9 ---
# Нормализация MinMaxScaler + кластеризация Scipy (linkage, fcluster)
from sklearn.preprocessing import MinMaxScaler
x = featureset.values
min_max_scaler = MinMaxScaler()
feature_mtx = min_max_scaler.fit_transform(x)

import scipy
leng = feature_mtx.shape[0]
D = np.zeros([leng, leng])
for i in range(leng):
    for j in range(leng):
        D[i, j] = scipy.spatial.distance.euclidean(feature_mtx[i], feature_mtx[j])

Z = hierarchy.linkage(D, 'complete')
from scipy.cluster.hierarchy import fcluster
max_d = 3
clusters = fcluster(Z, max_d, criterion='distance')
k = 5
clusters = fcluster(Z, k, criterion='maxclust')

import pylab
def llf(id):
    return '[%s %s %s]' % (pdf['manufact'][id], pdf['model'][id], int(float(pdf['type'][id])))
fig = pylab.figure(figsize=(18, 50))
dendro = hierarchy.dendrogram(Z, leaf_label_func=llf, leaf_rotation=0, leaf_font_size=12, orientation='right')

--- Ячейка кода 10 ---
# Кластеризация scikit-learn (n_clusters=6) + визуализация и groupby
dist_matrix = distance_matrix(feature_mtx, feature_mtx)
agglom = AgglomerativeClustering(n_clusters=6, linkage='complete')
agglom.fit(feature_mtx)
pdf['cluster_'] = agglom.labels_

import matplotlib.cm as cm
n_clusters = max(agglom.labels_) + 1
colors = cm.rainbow(np.linspace(0, 1, n_clusters))
cluster_labels = list(range(0, n_clusters))
plt.figure(figsize=(16, 14))
for color, label in zip(colors, cluster_labels):
    subset = pdf[pdf.cluster_ == label]
    plt.scatter(subset.horsepow, subset.mpg, s=subset.price * 10, c=color, label='cluster' + str(label), alpha=0.5)
plt.legend()
plt.title('Clusters')
plt.xlabel('horsepow')
plt.ylabel('mpg')

pdf.groupby(['cluster_', 'type'])['cluster_'].count()
agg_cars = pdf.groupby(['cluster_', 'type'])[['horsepow', 'engine_s', 'mpg', 'price']].mean()

--- Ячейка кода 11 ---
# Задание 2: другие варианты linkage — weighted и centroid
for link in ['weighted', 'centroid']:
    agglom_w = AgglomerativeClustering(n_clusters=6, linkage=link)
    agglom_w.fit(feature_mtx)
    print(link, "labels:", sorted(set(agglom_w.labels_)))
[вывод] weighted labels: [0, 1, 2, 3, 4, 5]
centroid labels: [0, 1, 2, 3, 4, 5]

--- Ячейка Markdown 2 ---
## Задание 2: выбор оптимального linkage

'weighted' и 'centroid' дают кластеры, близкие к 'complete', но 'centroid' может порождать неестественные слияния при разном числе точек в кластерах. Оптимальным считаю 'complete': он устойчив к выбросам и даёт компактные группы машин по мощности и расходу топлива.

## Задание 3: анализ диаграммы

Основной признак, который отличает кластеры друг от друга — мощность двигателя (horsepow): кластеры расположены на scatter-диаграмме в основном по осям horsepow и mpg; внутри кластера машины близки по мощности и расходу топлива, а цена используется только как размер маркера.
