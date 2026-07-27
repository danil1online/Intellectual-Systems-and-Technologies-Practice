# Практическая работа №6 Работа с облачными системами хранения и визуализации данных

---

## 🎯 Цель работы.

Приобрести практические навыки в области создания интеллектуальных систем с использованием современных средств разработки

---

## ⚠️ Важно

Это работа в формате **Notebook-based**. Вам будет доступен **ИИ-ментор** (`%%ask_mentor`). Все запросы логируются.

---

## 📚 Основные идеи и теоретические основы.

matplotlib – это основная библиотека для построения научных графиков в Python. 
Она включает функции для создания высококачественных визуализаций типа линейных диаграмм, гистограмм, диаграмм разброса и т.д. 
Визуализация данных и различных аспектов вашего анализа может дать важную информацию. 

В данной работе взаимодействие с matplotlib будет проходить в [Jupyter Notebook](Pr_3.md) на базе [Google Colab](https://colab.research.google.com/notebooks/intro.ipynb)
В среде Jupyter Notebook  возможно вывести рисунок прямо в браузере с помощью встроенных команд ```%matplotlib notebook``` и ```%matplotlib inline```.
Рекомендуется использовать ```%matplotlib inline```.

Основная библиотека для построения графиков, которую мы исследуем в этой лабораторной работе - это [Folium](https://python-visualization.github.io/folium/latest/).
Folium - это мощная библиотека Python, которая помогает создавать несколько типов карт. 
Тот факт, что результаты Folium интерактивны, делает эту библиотеку очень полезной для создания информационных панелей. 
Folium опирается на сильные стороны экосистемы Python и возможности сопоставления библиотеки Leaflet.js. 
Folium позволяет легко визуализировать данные, обработанные в Python, на интерактивной карте Leaflet. 
Библиотека имеет ряд встроенных наборов фрагментов из OpenStreetMap, Mapbox и Stamen и поддерживает настраиваемые наборы фрагментов с ключами API Mapbox или Cloudmade. 
Folium поддерживает наложения как GeoJSON, так и TopoJSON, а также привязку данных к этим наложениям для создания карт с цветовыми схемами.

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
  - [Folium](https://python-visualization.github.io/folium/latest/)
- [Набор данных]('https://github.com/shihao-wen/IBM-Data-Science-Professional-Certificate/blob/master/6.%20Data%20Visualization/Final%20Assignment/Police_Department_Incidents_-_Previous_Year__2016_.csv?raw=true):
  - Инциденты полицейского управления Сан-Франциско за 2016 год - инциденты полицейского управления из портала публичных данных Сан-Франциско. Инциденты получены из системы сообщений о преступлениях Департамента полиции Сан-Франциско (SFPD). Обновляется ежедневно, отображая данные за весь 2016 год.  
 
---

## 🧪 Программа работы 

---

### ⚙️ Настройка среды  

**Перейти по [ссылке](https://colab.research.google.com/notebooks/intro.ipynb)**

**В правом верхнем углу нажать кнопку «Войти» и затем ввести свои учетные данные google.**

**В верхнем левом углу найдите подменю «Файл», далее «Создать блокнот»**

**Устанавливаем библиотеку folium необходимой версии**
```python
!pip install folium
```

---


### 📌 Построение карт с отображение данных, хранимых на облачных серверах

  - Импортируем необходимые для работы библиотеки:
  ```python
  import numpy as np 
  import pandas as pd
  import folium
  ```
  - Создаем карты мира в Folium. Создаетcя объект Folium Map и затем запускается на отображение. Карты интерактивны, поэтому вы можете увеличивать любую интересующую область, несмотря на начальный уровень масштабирования.
  ```python
  world_map = folium.Map()
  world_map
  ```
  - Создаем карту с центром в Канаде и изменяем уровень масштабирования, чтобы увидеть, как он влияет на визуализированную карту.
  ```python
  world_map = folium.Map(location=[56.130, -106.35], zoom_start=4)
  world_map
  ```
  - Вы можете создавать карты разных стилей. Попробуйте различные [варианты](https://leaflet-extras.github.io/leaflet-providers/preview/) и выберите тот, который по Вашему мнению лучше всего.
  ```python
  world_map = folium.Map(location=[56.130, -106.35], zoom_start=4, tiles='OpenTopoMap')
  world_map
  ```
--
  ```python
  world_map = folium.Map(location=[56.130, -106.35], zoom_start=4, tiles='OPNVKarte')
  world_map
  ```
--
  ```python
  world_map = folium.Map(tiles='CyclOSM')
  world_map
  ```
-- 
  - Загружаем датасет и запрашиваем обзор его содержимого
  ```python
  df_incidents = pd.read_csv('https://github.com/shihao-wen/IBM-Data-Science-Professional-Certificate/blob/master/6.%20Data%20Visualization/Final%20Assignment/Police_Department_Incidents_-_Previous_Year__2016_.csv?raw=true')
  print('Набор данных загружен и прочитан в фреймворк данных Pandas!')
  df_incidents.head()
  ```
  - Объем датасета слишком большим, поэтому ограничиваем его до первых 500 записей.
  ```python
  limit = 500
  df_incidents = df_incidents.iloc[0:limit, :]
  ```
  - Визуализируем, где преступления имели место в городе Сан-Франциско.
Для примера использован стиль по умолчанию и начальный уровень масштабирования до 12 (Вам необходимо выбрать эти параметры самостоятельно).
  ```python
  latitude = 37.77
  longitude = -122.42
  sanfran_map = folium.Map(location=[latitude, longitude], zoom_start=12)  
  incidents = folium.map.FeatureGroup()
  for lat, lng, in zip(df_incidents.Y, df_incidents.X):
      incidents.add_child(
          folium.features.CircleMarker(
              [lat, lng],
              radius=5,
              color='yellow',
              fill=True,
              fill_color='blue',
              fill_opacity=0.6
          )
      )
  sanfran_map.add_child(incidents)
  ```
---

## 📌 Подготовить отчет о выполненной работе
В т.ч. изменить вид карты и представить результаты в отчете, а также подробно рассказать о библиотеке Folium и ее аналогах.
