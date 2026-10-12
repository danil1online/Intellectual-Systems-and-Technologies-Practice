--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Импорт библиотек для работы с картами
import numpy as np
import pandas as pd
import folium

--- Ячейка кода 3 ---
# Карта мира в Folium
world_map = folium.Map()
world_map

--- Ячейка кода 4 ---
# Карта с центром в Канаде, изменение масштаба
world_map = folium.Map(location=[56.130, -106.35], zoom_start=4)
world_map

--- Ячейка кода 5 ---
# Карты разных стилей (tiles)
folium.Map(location=[56.130, -106.35], zoom_start=4, tiles='OpenTopoMap')
folium.Map(location=[56.130, -106.35], zoom_start=4, tiles='OPNVKarte')
folium.Map(location=[56.130, -106.35], zoom_start=4, tiles='CyclOSM')

--- Ячейка кода 6 ---
# Загрузка датасета о преступлениях в Сан-Франциско
df_incidents = pd.read_csv('/shared/data/PD_2016.csv')
print('Набор данных загружен и прочитан в фреймворк данных Pandas!')
df_incidents.head()
[вывод] Набор данных загружен и прочитан в фреймворк данных Pandas!

--- Ячейка кода 7 ---
# Ограничение датасета до первых 500 записей
limit = 500
df_incidents = df_incidents.iloc[0:limit, :]
print(f"Записей в датасете: {len(df_incidents)}")
[вывод] Записей в датасете: 500

--- Ячейка кода 8 ---
# Карта мест преступлений в Сан-Франциско: маркеры-кружки
latitude = 37.77
longitude = -122.42
sanfran_map = folium.Map(location=[latitude, longitude], zoom_start=12)

incidents = folium.map.FeatureGroup()
for lat, lng in zip(df_incidents.Y, df_incidents.X):
    incidents.add_child(
        folium.features.CircleMarker(
            [lat, lng],
            radius=5,
            color='yellow',
            fill=True,
            fill_color='blue',
            fill_opacity=0.6,
        )
    )
sanfran_map.add_child(incidents)
sanfran_map

--- Ячейка Markdown 1 ---
## Ответы на контрольные вопросы

1. В отчёте представлены карты со стилями OpenTopoMap и OPNVKarte — выбран OpenTopoMap (лучше видна местность). Folium — библиотека для интерактивных веб-карт, обёртка над Leaflet (JavaScript); аналоги: plotly, bokeh, openlayers.
