--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Импорт библиотек
import numpy as np
import pandas as pd
from sklearn.tree import DecisionTreeClassifier
import matplotlib.pyplot as plt
%matplotlib inline

--- Ячейка кода 3 ---
# Чтение данных Drug 200
my_data = pd.read_csv("~/data/drug200.csv", delimiter=",")
my_data[0:5]
print("Размер датасета:", my_data.shape)
[вывод] Размер датасета: (200, 6)

--- Ячейка кода 4 ---
# Предварительная обработка: X, y и кодирование категориальных признаков
X = my_data[['Age', 'Sex', 'BP', 'Cholesterol', 'Na_to_K']].values
X[0:5]
y = my_data["Drug"]
y[0:5]

from sklearn import preprocessing
le_sex = preprocessing.LabelEncoder()
le_sex.fit(['F', 'M'])
X[:, 1] = le_sex.transform(X[:, 1])

le_BP = preprocessing.LabelEncoder()
le_BP.fit(['LOW', 'NORMAL', 'HIGH'])
X[:, 2] = le_BP.transform(X[:, 2])

le_Chol = preprocessing.LabelEncoder()
le_Chol.fit(['NORMAL', 'HIGH'])
X[:, 3] = le_Chol.transform(X[:, 3])

--- Ячейка кода 5 ---
# Разделение на train/test
from sklearn.model_selection import train_test_split
X_trainset, X_testset, y_trainset, y_testset = train_test_split(X, y, test_size=0.3, random_state=3)
print("X_trainset:", X_trainset.shape, "y_trainset:", y_trainset.shape)
print("X_testset:", X_testset.shape, "y_testset:", y_testset.shape)
[вывод] X_trainset: (140, 5) y_trainset: (140,)
X_testset: (60, 5) y_testset: (60,)

--- Ячейка кода 6 ---
# Разработка модели дерева решений
drugTree = DecisionTreeClassifier(criterion="entropy", max_depth=4)
drugTree.fit(X_trainset, y_trainset)

--- Ячейка кода 7 ---
# Классификация новых данных
predTree = drugTree.predict(X_testset)
print(predTree[0:5])
print(y_testset[0:5])
[вывод] ['Yeadson' 'Nasalin' 'Yeadson' 'Nasalin' 'Stemyl']
['Nasalin' 'Nasalin' 'Yeadson' 'Stemyl' 'Yeadson']

--- Ячейка кода 8 ---
# Оценка качества модели
from sklearn import metrics
print("DecisionTrees's Accuracy: ", metrics.accuracy_score(y_testset, predTree))
[вывод] DecisionTrees's Accuracy:  0.6833333333333333

--- Ячейка кода 9 ---
# Визуализация дерева (graphviz → PNG)
from six import StringIO
import pydotplus
import matplotlib.image as mpimg
from sklearn import tree

dot_data = StringIO()
filename = "drugtree.png"
featureNames = my_data.columns[0:5]
targetNames = my_data["Drug"].unique().tolist()
out = tree.export_graphviz(drugTree, feature_names=featureNames, out_file=dot_data,
                           class_names=np.unique(y_trainset), filled=True,
                           special_characters=True, rotate=False)
graph = pydotplus.graph_from_dot_data(dot_data.getvalue())
graph.write_png(filename)
img = mpimg.imread(filename)
plt.figure(figsize=(100, 200))
plt.imshow(img, interpolation='nearest')

--- Ячейка Markdown 1 ---
## Задание: анализ дерева решений

На первом этапе разделения данных дерево использует признак Na_to_K (порог ~20): он лучше всего разделяет классы и является основным. Далее по уровням важными становятся Age и Cholesterol; признаки Sex и BP участвуют в более глубоких узлах. Вывод: основное разделение данных происходит по электролиту Na_to_K, остальные признаки уточняют границы классов.
