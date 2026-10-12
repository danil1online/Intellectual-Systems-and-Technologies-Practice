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

# Микрозадание: выбросы от количества цилиндров
plt.scatter(cdf.CYLINDERS, cdf.CO2EMISSIONS, color='green')
plt.xlabel("CYLINDERS")
plt.ylabel("Emission")
plt.show()
[вывод] Зависимость выбросов от числа цилиндров монотонная и близка к линейной.

--- Ячейка кода 5 ---
# Разделение на обучающий и тестовый наборы (80/20)
msk = np.random.rand(len(df)) < 0.8
train = cdf[msk]
test = cdf[~msk]

--- Ячейка кода 6 ---
# Модель множественной линейной регрессии
from sklearn import linear_model
regr = linear_model.LinearRegression()
x = np.asanyarray(train[['ENGINESIZE', 'CYLINDERS', 'FUELCONSUMPTION_COMB']])
y = np.asanyarray(train[['CO2EMISSIONS']])
regr.fit(x, y)
print('Coefficients: ', regr.coef_)

--- Ячейка кода 7 ---
# Прогноз и оценка качества
y_hat = regr.predict(test[['ENGINESIZE', 'CYLINDERS', 'FUELCONSUMPTION_COMB']])
x = np.asanyarray(test[['ENGINESIZE', 'CYLINDERS', 'FUELCONSUMPTION_COMB']])
y = np.asanyarray(test[['CO2EMISSIONS']])

print("Residual sum of squares: %.2f" % np.mean((y_hat - y) ** 2))
print('Variance score: %.2f' % regr.score(x, y))
[вывод] Residual sum of squares: 104.53
Variance score: 0.88

--- Ячейка кода 8 ---
# Задание: модель с признаками FUELCONSUMPTION_CITY и FUELCONSUMPTION_HWY
regr_2 = linear_model.LinearRegression()
x_2 = np.asanyarray(train[['ENGINESIZE', 'CYLINDERS', 'FUELCONSUMPTION_CITY', 'FUELCONSUMPTION_HWY']])
y_2 = np.asanyarray(train[['CO2EMISSIONS']])
regr_2.fit(x_2, y_2)

y_hat_2 = regr_2.predict(test[['ENGINESIZE', 'CYLINDERS', 'FUELCONSUMPTION_CITY', 'FUELCONSUMPTION_HWY']])
x_t = np.asanyarray(test[['ENGINESIZE', 'CYLINDERS', 'FUELCONSUMPTION_CITY', 'FUELCONSUMPTION_HWY']])
y_t = np.asanyarray(test[['CO2EMISSIONS']])

print("Residual sum of squares: %.2f" % np.mean((y_hat_2 - y_t) ** 2))
print('Variance score: %.2f' % regr_2.score(x_t, y_t))
[вывод] Residual sum of squares: 106.77
Variance score: 0.87

--- Ячейка Markdown 1 ---
## Задание: анализ точности

Точность не повысится: variance score модели с CITY/HWY (0.87) чуть ниже, чем у базовой модели с COMB (0.88), а MSE выросла. Причина — мультиколлинеарность: COMB уже является линейной комбинацией CITY и HWY, поэтому добавление обоих признаков не несёт новой информации, а лишь увеличивает размерность модели.
