--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Гистограмма иммиграции за 2013 год
%matplotlib inline
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

df_can = pd.read_excel('/shared/data/Canada.xlsx',
          sheet_name='Canada by Citizenship',
          skiprows=range(20),
          skipfooter=2)
print('Данные загружены и записаны в dataframe!')

df_can[2013].head()

count, bin_edges = np.histogram(df_can[2013])
print(count)
print(bin_edges)

df_can[2013].plot(kind='hist', figsize=(8, 5))
plt.title('Гистограмма иммиграции из 195 стран в 2013 году')
plt.ylabel('Количество стран')
plt.xlabel('Количество иммигрантов')
plt.show()
[вывод] Данные загружены и записаны в dataframe!
[42, 47, 46, 33, 27]
[  0.    50.   100.   150.   200. 3800.]

--- Ячейка кода 3 ---
# Bar chart: иммиграция из Пакистана в Канаду, 1980-2013
df_can.set_index('OdName', inplace=True)
years = list(range(1980, 2014))
df_pakistan = df_can.loc['Pakistan', years]
df_pakistan.head()

df_pakistan.plot(kind='barh', figsize=(10, 6))
plt.xlabel('Год')
plt.ylabel('Количество иммигрантов')
plt.title('Иммиграция из Пакистана в Канаду с 1980 до 2013 гг.')
plt.show()

--- Ячейка Markdown 1 ---
## Ответы на контрольные вопросы

1. kind='barh' рисует горизонтальные бары, а kind='bar' — вертикальные; оси X и Y при этом меняются местами (годы оказываются по вертикали).
2. Заменяем 'Pakistan' на 'India': df_pakistan = df_can.loc['India', years] — получается barh-график иммиграции из Индии (Индия) за те же годы.
