# Практическая работа №9 Машинное обучение. Density-Based Clustering

---

## 🎯 Цель работы.

Получить теоретические знания и практические навыки постановки и решения задачи кластеризации методом Density-Based Clustering

## 📚 Основные идеи и теоретические основы.

Методы кластеризации, таких как метод k-средних, иерархическая и нечеткая кластеризация, используют для группировки данных.

При применении к задачам с кластерами сложной формы, например, при наличии кластера внутри другого кластера, традиционные методы могут не дать хороших результатов:
элементы в одном кластере могут иметь недостаточное сходство или точность / скорость могут быть низкими.

📚 Кластеризация Density-Based Clustering находит области с высокой плотностью, которые отделены друг от друга областями с низкой плотностью. 
Плотность в данном контексте определяется как количество точек в пределах заданного радиуса.

📚 Используемый в данной работе алгоритм DBSCAN является вариантом базового и расшифровывается как Density-Based Spatial Clustering of Applications with Noise (пространственная кластеризация приложений с учетом плотности). 
Этот метод — один из наиболее распространённых алгоритмов кластеризации, основанный на плотности объектов. 

📚 Идея заключается в том, что если определённая точка принадлежит кластеру, она должна находиться рядом с большим количеством других точек этого кластера.
Алгоритм работает на основе двух параметров: Epsilon и Minimum Points
Epsilon определяет заданный радиус, который, если включает в себя достаточное количество точек, называется _плотной областью_.
Minimum Points определяет минимальное количество точек данных, которое мы хотим получить в окрестности для определения такой совокупности точек, как _кластера_.

---

## 📁 Материалы и методы

- Операционная система - [Ubuntu 22.04](https://help.ubuntu.ru/wiki/командная_строка)
- Язык программирования – [python](https://www.python.org/).
- Основные технологии:
  -  [jupyter Notebook](https://jupyter.org/).
- Основные библиотеки:
  - [matplotlib](https://matplotlib.org/)
  - [numpy](https://numpy.org/)
  - [scikit-learn](https://scikit-learn.org/)
  - [pandas](https://pandas.pydata.org/)
- Датасет:
  - набор случайных данных
  - специальный датасет ["Weather Station"](https://www.kaggle.com/code/lykin22/weather-station-clustering-using-dbscan/output)

 
---

## 🧪 Программа работы 

---

### ⚙️ Настройка среды  

**Авторизоваться на сервере [Jupyter-Hub](https://jupyter.org/hub) по адресу [Jupyter-Hub-ИИСТ-НПИ](http://195.133.13.56:8000/)**

![Авторизация](https://github.com/danil1online/intelligent_information_and_measurement_systems/blob/main/images/autorization.png)

**С помощью файлового навигатора, расположенного слева перейти в свой каталог (ФИО и год), созданный ранее (двойным нажатием мыши)**

![Переход в каталог](../images/work_dir.png)

**Создать новую вкладку символом +**

![Создание новой вкладки](https://github.com/danil1online/intelligent_information_and_measurement_systems/blob/main/images/new_window_create.png)

**Выбрать тип новой вкладки -- Notebook**

![Создание вкладки Notebook](../images/notebook.png)

**Сохранить / переименовать файл**

![Создание вкладки Notebook](../images/save_new_file.png)

**Работать в новой вкладке вида**

![Владка Notebook](../images/notebook_clear_window.png)

**Импорт необходимых библиотек**

```python
import numpy as np 
from sklearn.cluster import DBSCAN 
# https://stackoverflow.com/questions/65898399/no-module-named-sklearn-datasets-samples-generator
from sklearn.datasets import make_blobs 
from sklearn.preprocessing import StandardScaler 
import matplotlib.pyplot as plt 
%matplotlib inline
import warnings
warnings.filterwarnings('ignore')
import pandas as pd
```

---

### 🧪 Density-Based Clustering на случайно сгенерированном наборе данных

1. 🧪 **Генерация набора случайных данных**
  - Функция, представленная ниже сгенерирует точки данных, если ей задать следующие входные данные:
    - ```centroidLocation``` - координаты центров, вокруг которых будут генерироваться случайные данные
    - ```numSamples``` - количество точек данных, которые мы хотим сгенерировать, разделенное на количество центров (количество центров определено в centroidLocation)
    - ```clusterDeviation``` - стандартное отклонение между кластерами; чем больше число, тем больше расстояние между ними
    ```python
    def createDataPoints(centroidLocation, numSamples, clusterDeviation):
      X, y = make_blobs(n_samples=numSamples, centers=centroidLocation, 
                                  cluster_std=clusterDeviation)
      
      X = StandardScaler().fit_transform(X)
      return X, y
    
    X, y = createDataPoints([[4,3], [2,-1], [-1,4]] , 1500, 0.5)
    ```

2. 🧪 **Настройка (обучение) модели K-Means**

```python
epsilon = 0.3
minimumSamples = 7
db = DBSCAN(eps=epsilon, min_samples=minimumSamples).fit(X)
labels = db.labels_
labels
```

3. 🧪 **Выбросы**

Выбросы - это точки, которые явно ошибочно были отнесены к тому или иному классу. 
Заменим все элементы в core_samples_mask, которые находятся в кластере, на «True», а если точки являются выбросами - на «False».

```python
core_samples_mask = np.zeros_like(db.labels_, dtype=bool)
core_samples_mask[db.core_sample_indices_] = True
core_samples_mask
```

```python
n_clusters_ = len(set(labels)) - (1 if -1 in labels else 0)
n_clusters_
```

```python
unique_labels = set(labels)
unique_labels
```

4. **Визуализация данных**

```python
colors = plt.cm.Spectral(np.linspace(0, 1, len(unique_labels)))
colors
```

```python
for k, col in zip(unique_labels, colors):
    if k == -1:
        # Black used for noise.
        col = 'k'

    class_member_mask = (labels == k)

    # Plot the datapoints that are clustered
    xy = X[class_member_mask & core_samples_mask]
    plt.scatter(xy[:, 0], xy[:, 1],s=50, c=col, marker=u'o', alpha=0.5)

    # Plot the outliers
    xy = X[class_member_mask & ~core_samples_mask]
    plt.scatter(xy[:, 0], xy[:, 1],s=50, c=col, marker=u'o', alpha=0.5)
```

 

--- 

### 📌 Задание №1

- Попробуйте кластеризовать указанный выше набор данных методом [k-средних](Pr_7.md), не создавая данные заново

---

### 🧪 Кластеризация метеостанций

DBSCAN особенно хорош для таких задач, где важен пространственный контекст. 
Преимущество алгоритма DBSCAN заключается в том, что он может находить кластеры любой произвольной формы, не подвергаясь влиянию шума. 
Например, в следующем примере кластеризуется местоположение метеостанций в Канаде.
Результаты решения такой задачи можно использовать, например, для поиска группы станций с одинаковыми погодными условиями. 
Алгоритм не только находит различные кластеры произвольной формы, но и может находить более плотные части выборок с центрированными данными, игнорируя менее плотные области или шумы.

Давайте начнём работать с данными. Мы будем работать по следующей схеме:

1. 🧪 **Загружаем данные из CSV-файла**

```python
filename='/home/jupyter/work/data/weather-stations20140101-20141231.csv'
pdf = pd.read_csv(filename)
pdf.head(5)
```

2. 🧪 **Предварительная обработка**

Удалим строки, в поле Tm которых нет значений

```python
pdf = pdf[pd.notnull(pdf["Tm"])]
pdf = pdf.reset_index(drop=True)
pdf.head(5)
```

3. 🧪 **Визуализация данных**

Визуализацию станций на карте выполним с помощью пакета basemap. 
Набор инструментов [matplotlib basemap](https://matplotlib.org/basemap/stable/) — это библиотека для построения двумерных данных на картах в Python. 
Basemap сам по себе не выполняет построение, но предоставляет возможности преобразования координат в картографические проекции.
Обратите внимание, что размер каждой точки данных представляет собой среднее значение максимальной температуры для каждой станции за год.
```python
from mpl_toolkits.basemap import Basemap
import matplotlib.pyplot as plt
from pylab import rcParams

rcParams['figure.figsize'] = (14,10)

llon=-140
ulon=-50
llat=40
ulat=65

pdf=pdf[(pdf['Long']>llon)&(pdf['Long']<ulon)&(pdf['Lat']>llat)&(pdf['Lat'] < ulat)]

my_map = Basemap(projection='merc',
            resolution = 'l', area_thresh = 1000.0,
            llcrnrlon=llon, llcrnrlat=llat,
            urcrnrlon=ulon, urcrnrlat=ulat) 

my_map.drawcoastlines()
my_map.drawcountries()
my_map.fillcontinents(color = 'white', alpha = 0.3)
my_map.shadedrelief()       

xs,ys = my_map(np.asarray(pdf.Long), np.asarray(pdf.Lat))
pdf['xm']= xs.tolist()
pdf['ym'] =ys.tolist()

for index,row in pdf.iterrows():
   my_map.plot(row.xm, row.ym,markerfacecolor =([1,0,0]),  
               marker='o', markersize= 5, alpha = 0.75)
plt.show()
```

4. 🧪 **Группировка станций по их местоположению, т. е. широте и долготе**

Библиотека DBSCAN из sklearn может запускать кластеризацию DBSCAN на основе векторного массива или матрицы расстояний.
В нашем случае мы передаем ей массив Numpy Clus_dataSet для поиска керновых образцов высокой плотности и расширяем кластеры на их основе.

```python
from sklearn.cluster import DBSCAN
import sklearn.utils
from sklearn.preprocessing import StandardScaler
sklearn.utils.check_random_state(1000)
Clus_dataSet = pdf[['xm','ym']]
Clus_dataSet = np.nan_to_num(Clus_dataSet)
Clus_dataSet = StandardScaler().fit_transform(Clus_dataSet)

db = DBSCAN(eps=0.15, min_samples=10).fit(Clus_dataSet)
core_samples_mask = np.zeros_like(db.labels_, dtype=bool)
core_samples_mask[db.core_sample_indices_] = True
labels = db.labels_
pdf["Clus_Db"]=labels

realClusterNum=len(set(labels)) - (1 if -1 in labels else 0)
clusterNum = len(set(labels)) 

pdf[["Stn_Name","Tx","Tm","Clus_Db"]].head(5)
```

С помощью команды ```set(labels)``` можно убедиться, что для выбросов метка кластера равна -1.
    
5. 🧪 **Визуализация кластеров на основе местоположения**
```python
from mpl_toolkits.basemap import Basemap
import matplotlib.pyplot as plt
from pylab import rcParams
%matplotlib inline
rcParams['figure.figsize'] = (14,10)

my_map = Basemap(projection='merc',
            resolution = 'l', area_thresh = 1000.0,
            #min longitude (llcrnrlon) and latitude (llcrnrlat)
            llcrnrlon=llon, llcrnrlat=llat, 
            #max longitude (urcrnrlon) and latitude (urcrnrlat)
            urcrnrlon=ulon, urcrnrlat=ulat) 

my_map.drawcoastlines()
my_map.drawcountries()
#my_map.drawmapboundary()
my_map.fillcontinents(color = 'white', alpha = 0.3)
my_map.shadedrelief()

colors = plt.get_cmap('jet')(np.linspace(0.0, 1.0, clusterNum))

for clust_number in set(labels):
    c=(([0.4,0.4,0.4]) if clust_number == -1 else colors[np.int64(clust_number)])
    clust_set = pdf[pdf.Clus_Db == clust_number]                    
    my_map.scatter(clust_set.xm, clust_set.ym, color =c,  
                   marker='o', s= 20, alpha = 0.85)
    if clust_number != -1:
        cenx=np.mean(clust_set.xm) 
        ceny=np.mean(clust_set.ym) 
        plt.text(cenx,ceny,str(clust_number), fontsize=25, color='red',)
        print ("Cluster "+str(clust_number)+', Avg Temp: '+ str(np.mean(clust_set.Tm)))
```

6. 🧪 **Группировка станций на основе их местоположения, средней, максимальной и минимальной температуры**
```python
from sklearn.cluster import DBSCAN
import sklearn.utils
from sklearn.preprocessing import StandardScaler
sklearn.utils.check_random_state(1000)
Clus_dataSet = pdf[['xm','ym','Tx','Tm','Tn']]
Clus_dataSet = np.nan_to_num(Clus_dataSet)
Clus_dataSet = StandardScaler().fit_transform(Clus_dataSet)

db = DBSCAN(eps=0.3, min_samples=10).fit(Clus_dataSet)
core_samples_mask = np.zeros_like(db.labels_, dtype=bool)
core_samples_mask[db.core_sample_indices_] = True
labels = db.labels_
pdf["Clus_Db"]=labels

realClusterNum=len(set(labels)) - (1 if -1 in labels else 0)
clusterNum = len(set(labels)) 

pdf[["Stn_Name","Tx","Tm","Clus_Db"]].head(5)
```

7. 🧪 **Визуализация кластеров на основе местоположения и температуры**
```python
from mpl_toolkits.basemap import Basemap
import matplotlib.pyplot as plt
from pylab import rcParams
%matplotlib inline
rcParams['figure.figsize'] = (14,10)

my_map = Basemap(projection='merc',
            resolution = 'l', area_thresh = 1000.0,
            #min longitude (llcrnrlon) and latitude (llcrnrlat)
            llcrnrlon=llon, llcrnrlat=llat, 
            #max longitude (urcrnrlon) and latitude (urcrnrlat)
            urcrnrlon=ulon, urcrnrlat=ulat) 

my_map.drawcoastlines()
my_map.drawcountries()
#my_map.drawmapboundary()
my_map.fillcontinents(color = 'white', alpha = 0.3)
my_map.shadedrelief()

colors = plt.get_cmap('jet')(np.linspace(0.0, 1.0, clusterNum))

for clust_number in set(labels):
    c=(([0.4,0.4,0.4]) if clust_number == -1 else colors[np.int64(clust_number)])
    clust_set = pdf[pdf.Clus_Db == clust_number]                    
    my_map.scatter(clust_set.xm, clust_set.ym, color =c,  
                   marker='o', s= 20, alpha = 0.85)
    if clust_number != -1:
        cenx=np.mean(clust_set.xm) 
        ceny=np.mean(clust_set.ym) 
        plt.text(cenx,ceny,str(clust_number), fontsize=25, color='red',)
        print ("Cluster "+str(clust_number)+', Avg Temp: '+ str(np.mean(clust_set.Tm)))
```

--- 

### 📌 Задание №2

Проведите анализ полученных визуализаций, сделайте выводы об их корректности, сформулируйте основные сомнения и предложения по доработке (например, необходимости дополнительных данных) 

### 📌 Подготовить отчет о выполненных Заданиях
