--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Построение 2D-графика синусоиды
%matplotlib inline
import matplotlib.pyplot as plt
import numpy as np

x = np.linspace(-10, 10, 100)
a = np.random.random()
y = a*np.sin(x)
plt.plot(x, y, marker="o")
plt.title("Синусоида")
plt.show()

--- Ячейка кода 3 ---
# Загрузка датасета об иммиграции в Канаду (1980-2013)
import numpy as np
import pandas as pd

df_can = pd.read_excel('/shared/data/Canada.xlsx',
          sheet_name='Canada by Citizenship',
          skiprows=range(20),
          skipfooter=2)
print('Данные загружены и записаны в dataframe!')
[вывод] Данные загружены и записаны в dataframe!

--- Ячейка кода 4 ---
# Подготовка данных: удалить служебные столбцы, переименовать, индекс — страна
df_can.drop(['AREA', 'REG', 'DEV', 'Type', 'Coverage'], axis=1, inplace=True)
df_can.rename(columns={'OdName':'Country', 'AreaName':'Continent','RegName':'Region'}, inplace=True)

all(isinstance(column, str) for column in df_can.columns)  # False — имена не все строки
df_can.columns = list(map(str, df_can.columns))
all(isinstance(column, str) for column in df_can.columns)  # True
df_can.set_index('Country', inplace=True)
df_can.head()

--- Ячейка кода 5 ---
# Столбец Total (сумма по годам), топ-5 стран, транспонирование
years = list(map(str, range(1980, 2014)))
df_can['Total'] = df_can[years].sum(axis=1)

df_can.sort_values(['Total'], ascending=False, axis=0, inplace=True)
df_top5 = df_can.head()
df_top5 = df_top5[years].transpose()
df_top5.head()

--- Ячейка кода 6 ---
# Диаграмма с областями: тренды иммиграции в 5 ведущих странах
%matplotlib inline
import matplotlib as mpl
import matplotlib.pyplot as plt

mpl.style.use('ggplot')

df_top5.index = df_top5.index.map(int)

df_top5.plot(kind='area',
             stacked=False,
             figsize=(20, 10),
             )

plt.title('Тенденции иммиграции в 5 ведущих странах')
plt.ylabel('Количество иммигрантов')
plt.xlabel('Год')
plt.show()

--- Ячейка Markdown 1 ---
## Ответы на контрольные вопросы

1. matplotlib — низкоуровневая библиотека построения графиков; pandas .plot() — обёртка над ней: df.plot(kind=...) под капотом вызывает функции plt, а тип графика задаётся параметром kind.
2. kind='area'; при stacked=False области рисуются рядом (без наложения), при stacked=True — складываются друг на друга.
