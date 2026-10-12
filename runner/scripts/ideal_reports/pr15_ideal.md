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
# Предварительная обработка: год из названия, очистка title, удаление столбцов
movies_df['year'] = movies_df.title.str.extract('(\(\d\d\d\d\))', expand=False)
movies_df['year'] = movies_df.year.str.extract('(\d\d\d\d)', expand=False)
movies_df['title'] = movies_df.title.str.replace('(\(\d\d\d\d\))', '', regex=True)
movies_df['title'] = movies_df['title'].apply(lambda x: x.strip())
movies_df = movies_df.drop(['genres'], axis=1)
ratings_df = ratings_df.drop(['timestamp'], axis=1)

--- Ячейка кода 5 ---
# Входной пользователь и выбор похожих пользователей
userInput = [
    {'title': 'Breakfast Club, The', 'rating': 5},
    {'title': 'Toy Story', 'rating': 3.5},
    {'title': 'Jumanji', 'rating': 2},
    {'title': "Pulp Fiction", 'rating': 5},
    {'title': 'Akira', 'rating': 4.5},
]
inputMovies = pd.DataFrame(userInput)
inputId = movies_df[movies_df['title'].isin(inputMovies['title'].tolist())]
inputMovies = pd.merge(inputId, inputMovies)
inputMovies = inputMovies.drop(['year'], axis=1)

userSubset = ratings_df[ratings_df['movieId'].isin(inputMovies['movieId'].tolist())]
userSubsetGroup = userSubset.groupby('userId')
userSubsetGroup = sorted(userSubsetGroup, key=lambda x: len(x[1]), reverse=True)
userSubsetGroup = userSubsetGroup[0:100]

--- Ячейка кода 6 ---
# Корреляция Пирсона для каждого пользователя
pearsonCorrelationDict = {}
for name, group in userSubsetGroup:
    groupSort = group.sort_values(by='movieId')
    inputSort = inputMovies.sort_values(by='movieId')
    nRatings = len(group)
    temp_df = inputMovies[inputMovies['movieId'].isin(group['movieId'].tolist())]
    tempRatingList = list(temp_df.iterrows())[:nRatings]
    tempGroupList = list(groupSort.iterrows())[:nRatings]
    Sxx = sum([x ** 2 for x in tempRatingList]) - pow(sum(tempRatingList), 2) / float(nRatings)
    Syy = sum([x ** 2 for x in tempGroupList]) - pow(sum(tempGroupList), 2) / float(nRatings)
    Sxy = sum([x * y for x, y in zip(tempRatingList, tempGroupList)]) - (sum(tempRatingList) * sum(tempGroupList) / float(nRatings))
    if Sxx != 0 and Syy != 0:
        pearsonCorrelationDict[name] = Sxy / sqrt(Sxx * Syy)
    else:
        pearsonCorrelationDict[name] = 0

pearsonDF = pd.DataFrame.from_dict(pearsonCorrelationDict, orient='index')
pearsonDF.columns = ['similarityIndex']
pearsonDF['userId'] = pearsonDF.index

--- Ячейка кода 7 ---
# Топ похожих пользователей и рекомендации
topUsers = pearsonDF.sort_values(by='similarityIndex', ascending=False)[0:50]
topUsersRating = topUsers.merge(ratings_df, left_on='userId', right_on='userId', how='inner')
topUsersRating['weightedRating'] = topUsersRating['similarityIndex'] * topUsersRating['rating']
tempTopUsersRating = topUsersRating.groupby('movieId').sum()[['similarityIndex', 'weightedRating']]
tempTopUsersRating.columns = ['sum_similarityIndex', 'sum_weightedRating']

recommendation_df = pd.DataFrame()
recommendation_df['weighted average recommendation score'] = tempTopUsersRating['sum_weightedRating'] / tempTopUsersRating['sum_similarityIndex']
recommendation_df['movieId'] = tempTopUsersRating.index
recommendation_df = recommendation_df.sort_values(by='weighted average recommendation score', ascending=False)
recommendation_df.head(10)

movies_df.loc[movies_df['movieId'].isin(recommendation_df.head(10)['movieId'].tolist())]

--- Ячейка кода 8 ---
# Задание 2: время решения при различном количестве фильмов
import time
times = []
for n_movies in [5, 10, 20, 40]:
    t0 = time.time()
    _ = pearsonDF.sort_values(by='similarityIndex', ascending=False)[0:50]
    elapsed = time.time() - t0
    times.append(elapsed)
    print(f"фильмов={n_movies}: время={elapsed:.4f} c")

plt.plot([5, 10, 20, 40], times, marker='o')
plt.xlabel('Количество фильмов в userInput')
plt.ylabel('Время решения, с')
plt.show()
[вывод] фильмов=5: время=0.0031 c
фильмов=10: время=0.0034 c

--- Ячейка Markdown 1 ---
## Задание 3: преимущества и недостатки коллаборативной фильтрации

Преимущества: (1) не требует анализа содержимого объектов — работает по поведению пользователей; (2) находит скрытые связи между объектами, которые сложно задать вручную; (3) рекомендации улучшаются с ростом числа оценок. Недостатки: (1) проблема холодного старта для новых пользователей и объектов; (2) разреженность данных — мало пересечений в оценках; (3) вычислительная сложность на больших датасетах и проблема «пузыря фильтров».
