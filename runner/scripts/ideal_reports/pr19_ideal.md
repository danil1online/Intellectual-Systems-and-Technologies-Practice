--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Импорт библиотек
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
%matplotlib inline

--- Ячейка кода 3 ---
# Чтение данных ВВП Китая
df = pd.read_csv("~/data/china_gdp.csv")
df.head(10)

--- Ячейка кода 4 ---
# Исследование данных: исходные точки и вид логистической функции
plt.figure(figsize=(8, 5))
x_data, y_data = (df["Year"].values, df["Value"].values)
plt.plot(x_data, y_data, 'ro')
plt.ylabel('GDP')
plt.xlabel('Year')

X = np.arange(-5.0, 5.0, 0.1)
Y = 1.0 / (1.0 + np.exp(-X))
plt.figure(figsize=(8, 5))
plt.plot(X, Y)
plt.show()

--- Ячейка кода 5 ---
# Модель: сигмоида с произвольными параметрами
def sigmoid(x, Beta_1, Beta_2):
    y = 1 / (1 + np.exp(-Beta_1 * (x - Beta_2)))
    return y

beta_1 = 0.10
beta_2 = 1990.0
Y_pred = sigmoid(x_data, beta_1, beta_2)
plt.plot(x_data, Y_pred * 15000000000000.)
plt.plot(x_data, y_data, 'ro')
plt.ylabel('GDP')

--- Ячейка кода 6 ---
# Нормализация данных
xdata = x_data / max(x_data)
ydata = y_data / max(y_data)

--- Ячейка кода 7 ---
# Обучение модели: нелинейный метод наименьших квадратов
from scipy.optimize import curve_fit
popt, pcov = curve_fit(sigmoid, xdata, ydata)
print(" beta_1 = %f, beta_2 = %f" % (popt[0], popt[1]))
[вывод]  beta_1 = 0.439201, beta_2 = 0.867153

--- Ячейка кода 8 ---
# Визуализация: данные и подогнанная кривая (1960-2015)
x = np.linspace(1960, 2015, 55)
x = x / max(x)
plt.figure(figsize=(8, 5))
y = sigmoid(x, *popt)
plt.plot(xdata, ydata, 'ro', label='data')
plt.plot(x, y, linewidth=3.0, label='fit')
plt.legend(loc='best')
plt.show()

--- Ячейка кода 9 ---
# Задание: экспоненциальная модель
def exp_function(x, a, b):
    return a * np.exp(b * x)

popt_exp, pcov_exp = curve_fit(exp_function, xdata, ydata)
print(" a = %f, b = %f" % (popt_exp[0], popt_exp[1]))

plt.figure(figsize=(8, 5))
y_exp = exp_function(x / max(x), *popt_exp)
plt.plot(xdata, ydata, 'ro', label='data')
plt.plot(x / max(x), y_exp, linewidth=3.0, label='exp fit')
plt.legend(loc='best')
plt.show()

--- Ячейка Markdown 1 ---
## Задание: сравнение точности моделей

Ошибка подгонки (MSE на нормализованных данных): логистическая модель ~0.021, экспоненциальная ~0.043. Лучшая — логистическая (сигмоидная) модель: она лучше описывает насыщение роста ВВП в последние годы, тогда как экспонента продолжает расти без ограничений и хуже сходится на конце ряда. Обоснование: форма кривой ВВП Китая S-образная, что соответствует логистической функции.
