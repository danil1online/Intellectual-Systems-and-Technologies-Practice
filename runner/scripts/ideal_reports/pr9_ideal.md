--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Импорт библиотек
import itertools
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.ticker import NullFormatter
import pandas as pd
import matplotlib.ticker as ticker
from sklearn import preprocessing
from sklearn.neighbors import KNeighborsClassifier
from sklearn import metrics
%matplotlib inline

--- Ячейка кода 3 ---
# Загрузка данных из CSV-файла
df = pd.read_csv("~/data/teleCust1000t.csv")
df['income'] = df['income'] * np.random.rand()
df.head()

--- Ячейка кода 4 ---
# Экспертный анализ: классы и распределение income
df['custcat'].value_counts()
df.hist(column='income', bins=50)
[вывод] 1    281
2    266
3    236
4    217

--- Ячейка кода 5 ---
# Признаки и классы
X = df[['region', 'tenure', 'age', 'marital', 'address', 'income', 'ed', 'employ', 'retire', 'gender', 'reside']].values
X[0:5]
y = df['custcat'].values
y[0:5]

--- Ячейка кода 6 ---
# Нормализация данных (нулевое среднее, единичная дисперсия)
X = preprocessing.StandardScaler().fit(X).transform(X.astype(float))
X[0:5]

--- Ячейка кода 7 ---
# Разделение на train/test 80/20
from sklearn.model_selection import train_test_split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=4)
print('Train set:', X_train.shape, y_train.shape)
print('Test set:', X_test.shape, y_test.shape)
[вывод] Train set: (800, 11) (800,)
Test set: (200, 11) (200,)

--- Ячейка кода 8 ---
# Обучение модели KNN, k=4
k = 4
neigh = KNeighborsClassifier(n_neighbors=k).fit(X_train, y_train)
yhat = neigh.predict(X_test)
yhat[0:5]

print("Train set Accuracy: ", metrics.accuracy_score(y_train, neigh.predict(X_train)))
print("Test set Accuracy: ", metrics.accuracy_score(y_test, yhat))
[вывод] Train set Accuracy:  0.6125
Test set Accuracy:  0.63

--- Ячейка кода 9 ---
# Задание: модели для k=1..9, Accuracy и F1-score
K = range(1, 10)
train_acc = []
test_acc = []
f1_scores = []
for k in K:
    neigh = KNeighborsClassifier(n_neighbors=k).fit(X_train, y_train)
    yhat_train = neigh.predict(X_train)
    yhat_test = neigh.predict(X_test)
    train_acc.append(metrics.accuracy_score(y_train, yhat_train))
    test_acc.append(metrics.accuracy_score(y_test, yhat_test))
    f1_scores.append(metrics.f1_score(y_test, yhat_test, average='weighted'))

plt.plot(list(K), test_acc, marker='o')
plt.xlabel('k')
plt.ylabel('Accuracy / F1')
plt.show()
for k in K:
    print(f"k={k}: accuracy={test_acc[k-1]:.3f}, f1={f1_scores[k-1]:.3f}")

--- Ячейка Markdown 1 ---
## Задание: анализ метрик и оптимальное k

Accuracy и F1-score растут до k=4-5, затем начинают колебаться из-за переобучения на малых k (k=1 даёт завышенный train и заниженный test). Оптимальное значение — k=4: баланс между точностью на тесте и устойчивостью.
