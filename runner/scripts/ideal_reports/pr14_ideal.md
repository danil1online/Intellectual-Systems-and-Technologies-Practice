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
%matplotlib inline
import matplotlib.pyplot as plt

--- Ячейка кода 3 ---
# Чтение данных
churn_df = pd.read_csv("~/data/ChurnData.csv")
churn_df.head()

--- Ячейка кода 4 ---
# Предварительная обработка и отбор данных
churn_df = churn_df[['tenure', 'age', 'address', 'income', 'ed', 'employ', 'equip', 'callcard', 'wireless', 'churn']]
churn_df['churn'] = churn_df['churn'].astype('int')
X = np.asarray(churn_df[['tenure', 'age', 'address', 'income', 'ed', 'employ', 'equip']])
y = np.asarray(churn_df['churn'])
X = preprocessing.StandardScaler().fit(X).transform(X)

--- Ячейка кода 5 ---
# Наборы для обучения и тестирования
from sklearn.model_selection import train_test_split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=4)
print('Train set:', X_train.shape, y_train.shape)
print('Test set:', X_test.shape, y_test.shape)
[вывод] Train set: (1728, 7) (1728,)
Test set: (432, 7) (432,)

--- Ячейка кода 6 ---
# Разработка модели Logistic Regression
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import confusion_matrix
LR = LogisticRegression(C=0.01, solver='liblinear').fit(X_train, y_train)

--- Ячейка кода 7 ---
# Классификация новых данных: предсказания и вероятности
yhat = LR.predict(X_test)
yhat_prob = LR.predict_proba(X_test)
yhat[0:5]

--- Ячейка кода 8 ---
# Оценка качества модели
from sklearn.metrics import jaccard_score
print("Jaccard index: ", jaccard_score(y_test, yhat, pos_label=1))

from sklearn.metrics import classification_report, confusion_matrix
import matplotlib.cm as cm

def plot_confusion_matrix(cm, classes, normalize=False, title='Confusion matrix', cmap=plt.cm.Blues):
    plt.figure()
    plt.imshow(cm, interpolation='nearest', cmap=cmap)
    plt.title(title)
    plt.colorbar()
    plt.xticks(range(len(classes)), classes)
    plt.yticks(range(len(classes)), classes)

print(confusion_matrix(y_test, yhat, labels=[1, 0]))
cnf_matrix = confusion_matrix(y_test, yhat, labels=[1, 0])
plot_confusion_matrix(cnf_matrix, classes=['churn=1', 'churn=0'], normalize=False, title='Confusion matrix')

print(classification_report(y_test, yhat))

from sklearn.metrics import log_loss
print("Log loss: ", log_loss(y_test, yhat_prob))
[вывод] Jaccard index:  0.3697478991596638
Log loss:  0.352

--- Ячейка кода 9 ---
# Задание 1: модели с решателями newton-cg, lbfgs, sag, saga
from sklearn.metrics import accuracy_score
for solver in ['newton-cg', 'lbfgs', 'sag', 'saga']:
    LR_s = LogisticRegression(C=0.01, solver=solver).fit(X_train, y_train)
    yhat_s = LR_s.predict(X_test)
    print(f"solver={solver}: accuracy={accuracy_score(y_test, yhat_s):.3f}")
[вывод] solver=newton-cg: accuracy=0.921
solver=lbfgs: accuracy=0.924
solver=sag: accuracy=0.924
solver=saga: accuracy=0.921

--- Ячейка Markdown 1 ---
## Задание 2: анализ решателей

liblinear — быстрый и устойчивый для небольших данных, но не поддерживает все ядра; newton-cg — хорошо масштабируется на разреженных данных, но может сходиться медленнее; lbfgs — по умолчанию, хороший баланс скорости и точности; sag/saga — стохастические градиентные методы, эффективны на больших выборках (saga — для L1/L2). Вывод: для этого датасета lbfgs и sag дают наилучшую точность при приемлемом времени.
