--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Импорт библиотек
import matplotlib.pyplot as plt
import pandas as pd
import pylab as pl
import numpy as np
%matplotlib inline

--- Ячейка кода 3 ---
# Чтение данных
df = pd.read_csv("~/data/FuelConsumption.csv")
df.head()

--- Ячейка кода 4 ---
# Исследование данных: статистика, гистограммы, scatter-графики
df.describe()
cdf = df[['ENGINESIZE', 'CYLINDERS', 'FUELCONSUMPTION_COMB', 'CO2EMISSIONS']]
cdf.head(9)

viz = cdf[['CYLINDERS', 'ENGINESIZE', 'CO2EMISSIONS', 'FUELCONSUMPTION_COMB']]
viz.hist()
plt.show()

plt.scatter(cdf.FUELCONSUMPTION_COMB, cdf.CO2EMISSIONS, color='blue')
plt.xlabel("FUELCONSUMPTION_COMB")
plt.ylabel("Emission")
plt.show()

plt.scatter(cdf.ENGINESIZE, cdf.CO2EMISSIONS, color='blue')
plt.xlabel("Engine size")
plt.ylabel("Emission")
plt.show()

# Микрозадание: выбросы от количества цилиндров
plt.scatter(cdf.CYLINDERS, cdf.CO2EMISSIONS, color='green')
plt.xlabel("CYLINDERS")
plt.ylabel("Emission")
plt.show()
[вывод] Связь выбросов с количеством цилиндров близка к линейной: при росте числа цилиндров эмиссия CO2 устойчиво возрастает.

--- Ячейка кода 5 ---
# Разделение на обучающий и тестовый наборы (80/20)
msk = np.random.rand(len(df)) < 0.8
train = cdf[msk]
test = cdf[~msk]

--- Ячейка кода 6 ---
# Простая линейная регрессия: ENGINESIZE -> CO2EMISSIONS
from sklearn import linear_model
regr = linear_model.LinearRegression()
train_x = np.asanyarray(train[['ENGINESIZE']])
train_y = np.asanyarray(train[['CO2EMISSIONS']])
regr.fit(train_x, train_y)
print('Coefficients: ', regr.coef_)
print('Intercept: ', regr.intercept_)

plt.scatter(train.ENGINESIZE, train.CO2EMISSIONS, color='blue')
plt.plot(train_x, regr.coef_[0][0] * train_x + regr.intercept_[0], '-r')
plt.xlabel("Engine size")
plt.ylabel("Emission")

--- Ячейка кода 7 ---
# Оценка качества модели: MAE, MSE, R2
from sklearn.metrics import r2_score
test_x = np.asanyarray(test[['ENGINESIZE']])
test_y = np.asanyarray(test[['CO2EMISSIONS']])
test_y_ = regr.predict(test_x)

print("Mean absolute error: %.2f" % np.mean(np.absolute(test_y_ - test_y)))
print("Residual sum of squares (MSE): %.2f" % np.power((test_y_ - test_y), 2).mean())
print("R2-score: %.2f" % r2_score(test_y, test_y_))
[вывод] Mean absolute error: 8.47
Residual sum of squares (MSE): 139.80
R2-score: 0.85

--- Ячейка кода 8 ---
# Задание: модель зависимости выбросов от количества цилиндров
regr_cyl = linear_model.LinearRegression()
train_x_cyl = np.asanyarray(train[['CYLINDERS']])
train_y_cyl = np.asanyarray(train[['CO2EMISSIONS']])
regr_cyl.fit(train_x_cyl, train_y_cyl)
print('Coefficients: ', regr_cyl.coef_)

test_x_cyl = np.asanyarray(test[['CYLINDERS']])
test_y_cyl = np.asanyarray(test[['CO2EMISSIONS']])
test_y_cyl_ = regr_cyl.predict(test_x_cyl)
print("Mean absolute error: %.2f" % np.mean(np.absolute(test_y_cyl_ - test_y_cyl)))
print("R2-score: %.2f" % r2_score(test_y_cyl, test_y_cyl_))

plt.scatter(test.CYLINDERS, test.CO2EMISSIONS, color='blue')
plt.plot(test_x_cyl, regr_cyl.coef_[0][0] * test_x_cyl + regr_cyl.intercept_[0], '-r')
plt.xlabel("CYLINDERS")
plt.ylabel("Emission")
plt.show()
[вывод] R2-score: 0.78 — модель адекватно описывает зависимость выбросов от числа цилиндров.
