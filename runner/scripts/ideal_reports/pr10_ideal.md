--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Импорт библиотек
import numpy as np
from sklearn.cluster import DBSCAN
from sklearn.datasets import make_blobs
from sklearn.preprocessing import StandardScaler
import matplotlib.pyplot as plt
%matplotlib inline
import pandas as pd
import warnings
warnings.filterwarnings('ignore')

--- Ячейка кода 3 ---
# Генерация набора случайных данных
def createDataPoints(centroidLocation, numSamples, clusterDeviation):
    X, y = make_blobs(n_samples=numSamples, centers=centroidLocation, cluster_std=clusterDeviation)
    X = StandardScaler().fit_transform(X)
    return X, y

X, y = createDataPoints([[4, 3], [2, -1], [-1, 4]], 1500, 0.5)
plt.scatter(X[:, 0], X[:, 1], marker='.')

--- Ячейка кода 4 ---
# Модель DBSCAN
epsilon = 0.3
minimumSamples = 7
db = DBSCAN(eps=epsilon, min_samples=minimumSamples).fit(X)
labels = db.labels_

--- Ячейка кода 5 ---
# Выбросы и число кластеров
core_samples_mask = np.zeros_like(db.labels_, dtype=bool)
core_samples_mask[db.core_sample_indices_] = True
n_clusters_ = len(set(labels)) - (1 if -1 in labels else 0)
unique_labels = set(labels)
print("Число кластеров:", n_clusters_)
[вывод] Число кластеров: 3

--- Ячейка кода 6 ---
# Визуализация: кластеры цветом, выбросы чёрным
colors = plt.cm.Spectral(np.linspace(0, 1, len(unique_labels)))
for k, col in zip(unique_labels, colors):
    if k == -1:
        col = 'k'
    class_member_mask = (labels == k)
    xy = X[class_member_mask & core_samples_mask]
    plt.scatter(xy[:, 0], xy[:, 1], s=50, c=[col], marker='o', alpha=0.5)

--- Ячейка кода 7 ---
# Задание 1: те же данные методом k-средних (без повторной генерации)
from sklearn.cluster import KMeans
k_means = KMeans(n_clusters=3, n_init=10).fit(X)
print("KMeans labels:", set(k_means.labels_))
[вывод] KMeans labels: {0, 1, 2}

--- Ячейка кода 8 ---
# Метеостанции: загрузка данных
filename = '~/data/weather-stations20140101-20141231.csv'
pdf = pd.read_csv(filename)
pdf.head(5)

--- Ячейка кода 9 ---
# Предварительная обработка: строки без Tm, сброс индекса
pdf = pdf[pd.notnull(pdf["Tm"])]
pdf = pdf.reset_index(drop=True)
print("Строк после очистки:", len(pdf))
[вывод] Строк после очистки: 492

--- Ячейка кода 10 ---
# Карта Канады (Basemap, Mercator)
from mpl_toolkits.basemap import Basemap
import matplotlib as mpl
mpl.rcParams['figure.figsize'] = (14, 10)

llon, ulon, llat, ulat = -140, -50, 40, 65
pdf = pdf[(pdf['Long'] > llon) & (pdf['Long'] < ulon) & (pdf['Lat'] > llat) & (pdf['Lat'] < ulat)]

my_map = Basemap(projection='merc', resolution='l', area_thresh=1000.0,
                 llcrnrlon=llon, llcrnrlat=llat, urcrnrlon=ulon, urcrnrlat=ulat)
my_map.drawcoastlines()
my_map.drawcountries()
my_map.fillcontinents(color='white', alpha=0.3)
xs, ys = my_map(np.asarray(pdf.Long), np.asarray(pdf.Lat))
pdf['xm'] = xs.tolist()
pdf['ym'] = ys.tolist()

--- Ячейка кода 11 ---
# Группировка станций по местоположению (xm, ym)
from sklearn.utils import check_random_state
check_random_state(1000)
Clus_dataSet = pdf[['xm', 'ym']]
Clus_dataSet = np.nan_to_num(Clus_dataSet)
Clus_dataSet = StandardScaler().fit_transform(Clus_dataSet)

db = DBSCAN(eps=0.15, min_samples=10).fit(Clus_dataSet)
labels = db.labels_
pdf["Clus_Db"] = labels
realClusterNum = len(set(labels)) - (1 if -1 in labels else 0)
print("Кластеров по местоположению:", realClusterNum)
[вывод] Кластеров по местоположению: 4

--- Ячейка кода 12 ---
# Группировка по местоположению + температурам (5 признаков)
Clus_dataSet = pdf[['xm', 'ym', 'Tx', 'Tm', 'Tn']]
Clus_dataSet = np.nan_to_num(Clus_dataSet)
Clus_dataSet = StandardScaler().fit_transform(Clus_dataSet)

db = DBSCAN(eps=0.3, min_samples=10).fit(Clus_dataSet)
labels = db.labels_
pdf["Clus_Db"] = labels
realClusterNum = len(set(labels)) - (1 if -1 in labels else 0)
print("Кластеров по местоположению и температуре:", realClusterNum)
[вывод] Кластеров по местоположению и температуре: 6

--- Ячейка кода 13 ---
# Визуализация кластеров на карте (jet, выбросы серые, подписи)
clusterNum = len(set(labels))
colors = plt.get_cmap('jet')(np.linspace(0.0, 1.0, clusterNum))
for clust_number in set(labels):
    c = ([0.4, 0.4, 0.4]) if clust_number == -1 else colors[np.int64(clust_number)]
    clust_set = pdf[pdf.Clus_Db == clust_number]
    my_map.scatter(clust_set.xm, clust_set.ym, color=c, marker='o', s=20, alpha=0.85)
    cenx, ceny = np.mean(clust_set.xm), np.mean(clust_set.ym)
    plt.text(cenx, ceny, str(clust_number), fontsize=25, color='red')
    print("Cluster " + str(clust_number) + ', Avg Temp: ' + str(np.mean(clust_set.Tm)))
[вывод] Cluster 0, Avg Temp: -12.4
Cluster 1, Avg Temp: 2.1

--- Ячейка Markdown 1 ---
## Задание 2: анализ визуализаций

Кластеры по местоположению корректно разделяют станции на географические зоны (запад/восток), однако кластеры по температуре внутри одной зоны неравномерны — часть станций с близкими координатами попала в разные кластеры. Сомнения: выбор eps=0.3 и min_samples=10 сделан без анализа silhouette; возможно, нужны дополнительные данные (высота над уровнем моря, тип местности). Предложение по доработке: подобрать eps через elbow-метод и добавить признак «высота станции».
