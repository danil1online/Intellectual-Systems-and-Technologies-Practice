# Практическая работа №4 Визуализация данных средствами MatplotLib. Основы 

---

## 🎯 Цель работы.

Получить навыки использования библиотеки визуализации данных Matplotlib с использованием языка программирования Python

---

## 📚 Основные идеи и теоретические основы.

matplotlib – это основная библиотека для построения научных графиков в Python. 
Она включает функции для создания высококачественных визуализаций типа линейных диаграмм, гистограмм, диаграмм разброса и т.д. 
Визуализация данных и различных аспектов вашего анализа может дать важную информацию. 

В данной работе взаимодействие с matplotlib будет проходить в [Jupyter Notebook](Pr_3.md) на базе [Google Colab](https://colab.research.google.com/notebooks/intro.ipynb)
В среде Jupyter Notebook  возможно вывести рисунок прямо в браузере с помощью встроенных команд ```%matplotlib notebook``` и ```%matplotlib inline```.
Рекомендуется использовать ```%matplotlib inline```.

---

## 📁 Материалы и методы

- Среда выполнения - [Google Colab](https://github.com/deepmipt/dlschl/wiki/Инструкция-по-работе-с-Google-Colab)
- Язык программирования – [python](https://www.python.org/).
- Основные технологии:
  -  [jupyter Notebook](https://jupyter.org/).
- Основные библиотеки:
  - [matplotlib](https://matplotlib.org/)
  - [numpy](https://numpy.org/)
  - [pandas](https://pandas.pydata.org/)
 
---

## 🧪 Программа работы 

---

### ⚙️ Настройка среды  

**Зарегистрировать электронную почту google (либо использовать существующий аккаунт)**

**Перейти по [ссылке](https://colab.research.google.com/notebooks/intro.ipynb)**

**В правом верхнем углу нажать кнопку «Войти» и затем ввести свои учетные данные google.**

**В верхнем левом углу найдите подменю «Файл», далее «Создать блокнот».**

---


### 📌 Выполнение простейшей последовательности команд

  - Опробовать программу для построения 2D графиков со следующим текстом:
  ```python
  %matplotlib inline
  import matplotlib.pyplot as plt 
  import numpy as np
  # Генерируем последовательность чисел от -10 до 10 с 100 шагами 
  x = np.linspace(-10, 10, 100) 
  # Генерируем случайную амплитуду для синусоиды
  a = np.random.random()
  # Создаем второй массив с помощью синуса 
  y = a*np.sin(x) 
  # Функция создает линейный график на основе двух массивов 
  plt.plot(x, y, marker="x")

  ```
### 📌 Работа с данными, загруженными из открытых источников сети интернет

В рамках данного пункта лабораторной работы будут использованы библиотеки Python pandas, Numpy. 
Стоит отметить, что библиотека pandas имеет встроенный построитель графиков plot, который и будет использоваться в данном пункте. 
Будет использован набор данных (dataset) об [Иммиграции в Канаду с 1980 по 2013 год - Международная миграция в отдельные страны и из них - Редакция 2015 года с веб-сайта Организации Объединенных Наций](https://www.un.org/en/development/desa/population/migration/data/empirical2/migrationflows.shtml). 
Набор данных содержит годовые данные о потоках международных мигрантов, регистрируемых различными странами. 
Данные показывают как приток, так и отток в зависимости от места рождения, гражданства или места предыдущего / следующего проживания как для иностранцев, так и для граждан. 
В рамках данного пункта мы сосредоточимся на данных иммиграционной службы Канады.

  - Загрузка и подготовка данных.
    - Импорт первичных библиотек - pandas, Numpy.
    ```python
    import numpy as np
    import pandas as pd
    ```
    - Загрузка данных из сети интернет в pandas dataframe.
    ```python
    df_can = pd.read_excel('https://s3-api.us-geo.objectstorage.softlayer.net/cf-courses-data/CognitiveClass/DV0101EN/labs/Data_Files/Canada.xlsx',
              sheet_name='Canada by Citizenship',
              skiprows=range(20),
              skipfooter=2)
    print('Данные загружены и записаны в dataframe!')
    ```
    - Обзор данных – первые 5 элементов:
    ```python
    df_can.head()
    ```
    - Обзор данных – размер (строки и столбы) dataset’а:
    ```python
    print(df_can.shape)
    ```
    - Очистка данных – удаление неинформативных для нас столбцов, повторный вывод первых 5 строк:
    ```python
    df_can.drop(['AREA', 'REG', 'DEV', 'Type', 'Coverage'], axis=1, inplace=True)
    df_can.head()
    ```
    - Приведение данных к более удобному виду – переименование нескольких столбцов, повторный вывод первых 5 строк:
    ```python
    df_can.rename(columns={'OdName':'Country', 'AreaName':'Continent','RegName':'Region'}, inplace=True)
    df_can.head()
    ```
    - Проверка структуры данных – уточняем, являются ли наименования всех столбцов типами «строка» («string»):
    ```python
    all(isinstance(column, str) for column in df_can.columns)
    ```
    Результатом будет скорее всего False. Поэтому выполняем преобразование.
    - Изменяем наименование всех столбцов так, чтобы они были типа string и проверяем заново:
    ```python
    df_can.columns = list(map(str, df_can.columns))
    all(isinstance(column, str) for column in df_can.columns)
    ```
    - Приведение данных к более удобному виду – задаем в качестве строчного индекса наименование страны, повторный вывод первых 5 строк:
    ```python
    df_can.set_index('Country', inplace=True)
    df_can.head()
    ```
    - Расширяем данные – создаем новый столбец Total, который будет являться суммой всех столбцов, соответствующих годам (фактически – количеством иммигрантов за все года с 1980 по 2013), повторный вывод первых 5 строк:
    ```python
    # Выбираем только столбцы с годами для суммирования
    years = list(map(str, range(1980, 2014)))
    df_can['Total'] = df_can[years].sum(axis=1)
    df_can.head()
    ```
    - Создаем новый набор данных на базе предыдущего – выделяем в него 5 стран, иммиграция из которых больше всех остальных:
    ```python
    years = list(map(str, range(1980, 2014)))
    df_can.sort_values(['Total'], ascending=False, axis=0, inplace=True)
    df_top5 = df_can.head()
    # Транспонирование таблицы
    df_top5 = df_top5[years].transpose() 
    df_top5.head()
    ```
    - Вывод данных в виде графика типа «Диаграмма с областями»:
    ```python
    %matplotlib inline 
    
    import matplotlib as mpl
    import matplotlib.pyplot as plt
    
    mpl.style.use('ggplot') # опционально: задаем стиль ggplot
    
    # Проверяем версию Matplotlib
    print ('Matplotlib version: ', mpl.__version__) # >= 2.0.0
    
    # Для построения графика изменяем тип индексов строк (года) 
    # на integer
    df_top5.index = df_top5.index.map(int) 
    # Построение графика типа ‘area’ встроенной 
    # в pandas суб-библиотекой matplotlib
    df_top5.plot(kind='area', 
                 stacked=False,
                 figsize=(20, 10), # размер области построения графика
                 )
    #Задаем наименование графика
    plt.title('Immigration Trend of Top 5 Countries')
    #Задаем наименование оси Y
    plt.ylabel('Number of Immigrants')
    #Задаем наименование оси X
    plt.xlabel('Years')
    # Выводим график со всеми параметрами на экран
    plt.show()
    ```
    
---

## 📌 Подготовить отчет о выполненной работе
В т.ч. ответить на следующие вопросы:
  - Чем отличается построение графиков с помощью matplotlib и pandas?
  - Какое значение параметра kind нужно задать функции plot для вывода графика типа «Диаграмма с областями»?
