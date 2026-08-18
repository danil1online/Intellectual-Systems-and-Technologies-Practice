# Практическая работа №6: Визуализация данных средствами MatplotLib. Диаграммы

---

## 🎯 Цель работы.

Получить навыки использования библиотеки визуализации данных Matplotlib с использованием языка программирования Python

---

## ⚠️ Важно

Это работа в формате **Notebook-based**. Вам будет доступен **ИИ-ментор** (`%%ask_mentor`). Модель кроме ответа дает оценку качества вопроса.

---

## 📚 Основные идеи и теоретические основы.

matplotlib – это основная библиотека для построения научных графиков в Python. 
Она включает функции для создания высококачественных визуализаций типа линейных диаграмм, гистограмм, диаграмм разброса и т.д. 
Визуализация данных и различных аспектов вашего анализа может дать важную информацию. 

В данной работе взаимодействие с matplotlib будет проходить в Jupyter Notebook
В среде Jupyter Notebook  возможно вывести рисунок прямо в браузере с помощью встроенных команд ```%matplotlib notebook``` и ```%matplotlib inline```.
Рекомендуется использовать ```%matplotlib inline```.

Гистограмма - это способ представления частотного распределения числового набора данных. 
Она работает так: ось x разбивается на ячейки, каждая точка данных в наборе данных назначается ячейке, а затем подсчитывается количество точек данных, назначенных каждой ячейке. 
Таким образом, ось Y - это частота или количество точек данных в каждой ячейке. 
Мы можем изменять размеры, и обычно их нужно настроить, чтобы распределение отображалось красиво. 

Bar Charts – это способ представления данных, где длина полосок представляет величину / размер функции / переменной. 
Bar Charts обычно представляют числовые и категориальные переменные, сгруппированные по интервалам.

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

Создайте новый каталог `Pr_6`

Создайте новый Jupyter Notebook: **File → New → Notebook → Python 3 (ipykernel)**.

Сохраните новый Jupyter Notebook под именем `Pr_6_report.ipynb` (в `~/project/reports/Pr_6`)

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

### 🧪 Построение Гистограмм

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
  - Обзор данных
  ```python
  df_can['2013'].head()
  ```
  - Подготовка данных для гистограммы
  ```python
  count, bin_edges = np.histogram(df_can['2013'])
  
  print(count) # подсчет частоты появления данных
  print(bin_edges) # количество столбцов, по умолчанию – 10
  ```
  - Построение гистограммы:
  ```python
  df_can['2013'].plot(kind='hist', figsize=(8, 5))
  plt.title('Гистограмма иммиграции из 195 стран в 2013 году') # добавление названия
  plt.ylabel('Количество стран') # добавление наименования оси у
  plt.xlabel('Количество иммигрантов') # наименование оси х
  plt.show()
  ```
### 🧪 Построение Bar Charts (Dataframe)

  - Извлекаем часть данных из df_can:
    ```python
    df_pakistan = df_can.loc['Pakistan', years]
    df_pakistan.head()
    ```
  - Построение графика (горизонтальный Bar Chart):
    ```python
    df_pakistan.plot(kind='barh', figsize=(10, 6))
    plt.xlabel('Год') # add to x-label to the plot
    plt.ylabel('Количество иммигрантов') # add y-label to the plot
    plt.title('Иммиграция из Пакистана в Канаду с 1980 до 2013 гг.') # add title to the plot
    plt.show()
    ```    
---

## 📌 Отчёт о выполненной работе после выполнения заданий / завершения занятия

1. Добавьте в конец Jupyter Notebook `Pr_6_report.ipynb` Markdown-ячейку с ответами на контрольные вопросы из раздела [«Контрольные вопросы»](Pr_6.md#контрольные-вопросы)
   - Тип ячейки выбирается в верхней части окна Jupyter Notebook'а из выпадающего списка, где по умолчанию стоит значение `Code`
3. Сохраните Jupyter Notebook
4. Загрузите файл в свой репозиторий в GitLab:
   - В левом окне Jupyter Lab (файловом менеджере) перейдите в каталог `project` (поднимитесь на два уровня вверх: из `Pr_6` в `reports` -> `project`)
   - Создайте новую вкладку типа `Terminal` (File -> New -> Terminal)
   - Введите

```bash
git add .
git commit -m "Pr_6 notebook report"
git push
```

> ⏳ Оценка запустится автоматически в GitLab CI. Результат появится в разделе **CI/CD → Pipelines**.

---

## Контрольные вопросы
1. Попробуйте изменить kind='barh' на kind='bar', что получится?
2. Постройте последний график не для Пакистана, а для Индии. 
