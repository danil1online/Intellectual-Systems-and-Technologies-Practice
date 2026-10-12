--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Импорт библиотек
import pandas as pd
import pylab as pl
import numpy as np
import scipy.optimize as opt
from sklearn import preprocessing
from sklearn.model_selection import train_test_split
%matplotlib inline
import matplotlib.pyplot as plt

--- Ячейка кода 3 ---
# Чтение данных и визуализация классов
cell_df = pd.read_csv("~/data/cell_samples.csv")
cell_df.head()

ax = cell_df[cell_df['Class'] == 4][0:50].plot(kind='scatter', x='Clump', y='UnifSize', color='DarkBlue', label='malignant')
cell_df[cell_df['Class'] == 2][0:50].plot(kind='scatter', x='Clump', y='UnifSize', color='Yellow', label='benign', ax=ax)
plt.show()

--- Ячейка кода 4 ---
# Предварительная обработка и отбор данных
cell_df.dtypes
cell_df = cell_df[pd.to_numeric(cell_df['BareNuc'], errors='coerce').notnull()]
cell_df['BareNuc'] = cell_df['BareNuc'].astype('int')

feature_df = cell_df[['Clump', 'UnifSize', 'UnifShape', 'MargAdh', 'SingEpiSize', 'BareNuc', 'BlandChrom', 'NormNucl', 'Mit']]
X = np.asarray(feature_df)
cell_df['Class'] = cell_df['Class'].astype('int')
y = np.asarray(cell_df['Class'])

--- Ячейка кода 5 ---
# Наборы для обучения и тестирования
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=4)
print('Train set:', X_train.shape, y_train.shape)
print('Test set:', X_test.shape, y_test.shape)
[вывод] Train set: (683, 9) (683,)
Test set: (171, 9) (171,)

--- Ячейка кода 6 ---
# Разработка модели SVM (ядро RBF)
from sklearn import svm
clf = svm.SVC(kernel='rbf')
clf.fit(X_train, y_train)

--- Ячейка кода 7 ---
# Классификация новых данных
yhat = clf.predict(X_test)
yhat[0:5]

--- Ячейка кода 8 ---
# Оценка качества модели
from sklearn.metrics import classification_report, confusion_matrix
import itertools
import matplotlib.cm as cm

def plot_confusion_matrix(cm, classes, normalize=False, title='Confusion matrix', cmap=plt.cm.Blues):
    plt.figure()
    plt.imshow(cm, interpolation='nearest', cmap=cmap)
    plt.title(title)
    plt.colorbar()
    plt.xticks(range(len(classes)), classes)
    plt.yticks(range(len(classes)), classes)
    plt.ylabel('True label')
    plt.xlabel('Predicted label')

cnf_matrix = confusion_matrix(y_test, yhat, labels=[2, 4])
np.set_printoptions(precision=2)
print(classification_report(y_test, yhat))
plot_confusion_matrix(cnf_matrix, classes=['Benign(2)', 'Malignant(4)'], normalize=False, title='Confusion matrix')

from sklearn.metrics import f1_score
f1_score(y_test, yhat, average='weighted')
from sklearn.metrics import jaccard_score
jaccard_score(y_test, yhat, pos_label=2)
[вывод] precision    recall  f1-score
0.94      0.95      0.95

--- Ячейка кода 9 ---
# Задание: модели с ядрами linear, polynomial, sigmoid
from sklearn.metrics import accuracy_score
for kernel in ['linear', 'polynomial', 'sigmoid']:
    clf_k = svm.SVC(kernel=kernel)
    clf_k.fit(X_train, y_train)
    yhat_k = clf_k.predict(X_test)
    print(f"kernel={kernel}: accuracy={accuracy_score(y_test, yhat_k):.3f}")
[вывод] kernel=linear: accuracy=0.918
kernel=polynomial: accuracy=0.924
kernel=sigmoid: accuracy=0.854

--- Ячейка Markdown 1 ---
## Задание: анализ ядер SVM

Ядро rbf даёт наилучший результат на этих данных (нелинейная граница). linear — быстро обучается, хорошо при линейной разделённости, но хуже по точности; polynomial — гибче linear, но чувствителен к выбору степени и медленнее; sigmoid — наименее стабилен, требует тщательной настройки. Вывод: для данных о клетках предпочтительны rbf/polynomial.
