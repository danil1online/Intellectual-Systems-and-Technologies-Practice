# Практическая работа №5: Визуализация данных средствами MatplotLib. Основы 

---

## 🎯 Цель работы.

Получить навыки использования библиотеки визуализации данных Matplotlib с использованием языка программирования Python

---

## ⚠️ Важно

Это работа в формате **Notebook-based**. Вам будет доступен **ИИ-ментор** (`%%ask_mentor`). Все запросы оцениваются.

---

## 📚 Основные идеи и теоретические основы.

matplotlib – это основная библиотека для построения научных графиков в Python. 
Она включает функции для создания высококачественных визуализаций типа линейных диаграмм, гистограмм, диаграмм разброса и т.д. 
Визуализация данных и различных аспектов вашего анализа может дать важную информацию. 

В данной работе взаимодействие с matplotlib будет проходить в [Jupyter Notebook](Pr_5.md)
В среде Jupyter Notebook возможно вывести рисунок прямо в браузере с помощью встроенных команд ```%matplotlib notebook``` и ```%matplotlib inline```.
Рекомендуется использовать ```%matplotlib inline```.

---

## 📁 Материалы и методы

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

**Откройте JupyterHub**: `http://<server-ip>:8000`, войдите под своей учётной записью.

В левой части Jupyter Lab перейдите (предположим, Вы находитесь в своем корневом каталоге `~`) в `project` -> `reports`

Создайте новый каталог `Pr_5`

Создайте новый Jupyter Notebook: **File → New → Notebook → Python 3 (ipykernel)**.

Сохраните новый Jupyter Notebook под именем `Pr_5_report.ipynb` (в `~/project/reports/Pr_5`)

Введите первый блок кода в первую ячейку — проверка версии Python:

```python
import sys
print(f"Python version: {sys.version}")
```

**Далее приведены задания для самостоятельного выполнения**. 

В ходе выполнения рекомендуется комментировать код. Комментарии в Python начинаются с символа `#`, все, что следует за ним, не будет выполнено. 

При появлении ошибок и наличии вопросов рекомендуется использовать встроенного ИИ-ментора, например
```python
%%ask_mentor
Почему при выполнении freq = {word: len(words) for word, words in [("cat", 3), ("dog", 4)]} появляется ошибка
TypeError                                 Traceback (most recent call last)
Cell In[8], line 46
     44 squares_dict = {x: x ** 2 for x in range(1, 6)}
     45 # {1: 1, 2: 4, 3: 9, 4: 16, 5: 25}
---> 46 freq = {word: len(words) for word, words in [("cat", 3), ("dog", 4)]}

Cell In[8], line 46, in <dictcomp>(.0)
     44 squares_dict = {x: x ** 2 for x in range(1, 6)}
     45 # {1: 1, 2: 4, 3: 9, 4: 16, 5: 25}
---> 46 freq = {word: len(words) for word, words in [("cat", 3), ("dog", 4)]}

TypeError: object of type 'int' has no len()
```

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
  plt.plot(x, y, marker="o")

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
    plt.title('Тенденции иммиграции в 5 ведущих странах')
    #Задаем наименование оси Y
    plt.ylabel('Количество иммигрантов')
    #Задаем наименование оси X
    plt.xlabel('Год')
    # Выводим график со всеми параметрами на экран
    plt.show()
    ```
    
---

## 📌 Отчёт о выполненной работе после выполнения заданий / завершения занятия

1. Добавьте в конец Jupyter Notebook `Pr_5_report.ipynb` Markdown-ячейку с ответами на контрольные вопросы из раздела [«Контрольные вопросы»](Pr_5.md#контрольные-вопросы)
   - Тип ячейки выбирается в верхней части окна Jupyter Notebook'а из выпадающего списка, где по умолчанию стоит значение `Code`
3. Сохраните Jupyter Notebook
4. Загрузите файл в свой репозиторий в GitLab:
   - В левом окне Jupyter Lab (файловом менеджере) перейдите в каталог `project` (поднимитесь на два уровня вверх: из `Pr_5` в `reports` -> `project`)
   - Создайте новую вкладку типа `Terminal` (File -> New -> Terminal)
   - Введите

```bash
git add .
git commit -m "Pr_5 notebook report"
git push
```

> ⏳ Оценка запустится автоматически в GitLab CI. Результат появится в разделе **CI/CD → Pipelines**.

---

## Контрольные вопросы
1. Чем отличается построение графиков с помощью matplotlib и pandas?
2. Какое значение параметра kind нужно задать функции plot для вывода графика типа «Диаграмма с областями»?
