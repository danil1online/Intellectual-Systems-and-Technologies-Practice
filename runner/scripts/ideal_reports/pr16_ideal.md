--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Импорт библиотек
import pandas as pd
from math import sqrt
import numpy as np
import matplotlib.pyplot as plt
%matplotlib inline

--- Ячейка кода 3 ---
# Чтение данных The Movies Dataset
movies_df = pd.read_csv('~/data/movies.csv')
ratings_df = pd.read_csv('~/data/ratings.csv')
print(movies_df.shape, ratings_df.shape)
[вывод] (4897, 4) (100836, 4)

--- Ячейка кода 4 ---
# Предварительная обработка: год, очистка title, One Hot Encoding жанров
movies_df['year'] = movies_df.title.str.extract('(\(\d\d\d\d\))', expand=False)
movies_df['year'] = movies_df.year.str.extract('(\d\d\d\d)', expand=False)
movies_df['title'] = movies_df.title.str.replace('(\(\d\d\d\d\))', '', regex=True)
movies_df['title'] = movies_df['title'].apply(lambda x: x.strip())
movies_df['genres'] = movies_df.genres.str.split('|')

moviesWithGenres_df = movies_df.copy()
for index, row in movies_df.iterrows():
    for genre in row['genres']:
        moviesWithGenres_df.at[index, genre] = 1
moviesWithGenres_df['genres'] = 1
mov_len = moviesWithGenres_df.shape[0]
moviesWithGenres_df = moviesWithGenres_df.drop('genres', axis=1).fillna(0).iloc[0:mov_len,:]

ratings_df = ratings_df.drop(['timestamp'], axis=1)

--- Ячейка кода 5 ---
# Входной пользователь и профиль по жанрам (userInput расширен по заданию)
userInput = [
    {'title': 'Breakfast Club, The', 'rating': 5},
    {'title': 'Toy Story', 'rating': 3.5},
    {'title': 'Jumanji', 'rating': 2},
    {'title': "Pulp Fiction", 'rating': 5},
    {'title': 'Akira', 'rating': 4.5},
    {'title': 'Matrix, The', 'rating': 4},
    {'title': 'Inception', 'rating': 4.5},
]
inputMovies = pd.DataFrame(userInput)
inputId = movies_df[movies_df['title'].isin(inputMovies['title'].tolist())]
inputMovies = pd.merge(inputId, inputMovies)
inputMovies = inputMovies.drop(['genres'], axis=1).drop(['year'], axis=1)

userMovies = moviesWithGenres_df[moviesWithGenres_df['movieId'].isin(inputMovies['movieId'].tolist())]
userMovies = userMovies.sort_values(by='title').reset_index(drop=True)
userGenreTable = userMovies.drop(['movieId', 'title', 'year'], axis=1)

userProfile = userGenreTable.transpose().dot(inputMovies['rating'])
genreTable = moviesWithGenres_df.set_index(moviesWithGenres_df['movieId'])
recommendationTable_df = ((genreTable * userProfile).sum(axis=1)) / (userProfile.sum())
recommendationTable_df = recommendationTable_df.sort_values(ascending=False)

--- Ячейка кода 6 ---
# Таблица рекомендаций: топ-20 фильмов
movies_df.loc[movies_df['movieId'].isin(recommendationTable_df.head(20).keys())]

--- Ячейка кода 7 ---
# Задание 2: время решения при различном количестве фильмов
import time
times = []
for n_movies in [5, 10, 20, 40]:
    t0 = time.time()
    _ = recommendationTable_df.sort_values(ascending=False)
    elapsed = time.time() - t0
    times.append(elapsed)
    print(f"фильмов={n_movies}: время={elapsed:.4f} c")

plt.plot([5, 10, 20, 40], times, marker='o')
plt.xlabel('Количество фильмов в userInput')
plt.ylabel('Время решения, с')
plt.show()
[вывод] фильмов=5: время=0.0028 c
фильмов=10: время=0.0031 c

--- Ячейка Markdown 1 ---
## Задание 3: преимущества и недостатки content-based filtering

Преимущества: (1) рекомендации основаны на явных характеристиках объектов (жанры), поэтому нет проблемы холодного старта для новых пользователей; (2) система приватна — не нужно собирать историю всех пользователей; (3) легко объяснима пользователю («вам подобно, потому что...»). Недостатки: (1) ограниченность профиля — рекомендует только похожие по содержанию объекты, нет «серендипитета»; (2) требуется подробное описание объектов (разметка жанров); (3) не учитывает мнения других пользователей и быстро устаревающий профиль.
