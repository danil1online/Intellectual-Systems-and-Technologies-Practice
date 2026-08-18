# Практическая работа №2: Знакомство с Python. Структуры данных и циклы

---

## 🎯 Цель работы

Приобрести практические навыки работы с основными структурами данных Python (списки, словари, кортежи, множества) и организации циклов (for, while) с управляющими конструкциями.

---

## ⚠️ Важно

Это работа в формате **Notebook-based**. Вам будет доступен **ИИ-ментор** (`%%ask_mentor`). Модель кроме ответа дает оценку качества вопроса.

---

## 📚 Основные идеи и теоретические основы.

### Списки [(list)](https://pythonworld.ru/tipy-dannyx-v-python/spiski-list-funkcii-i-metody-spiskov.html)

Список — *упорядоченная* изменяемая коллекция элементов. Элементы обращаются по индексу (начиная с 0). 

Ниже показаны примеры использования и после знака `#` -- ожидаемый результат. 

```python
# Создание списков
numbers = [1, 2, 3, 4, 5]
mixed = [1, "hello", 3.14, True]
empty = []
empty2 = list()

# Индексация (отрицательная — с конца)
print(numbers[0])   # 1
print(numbers[-1])  # 5

# Срезы [start:stop:step]
print(numbers[1:4])    # [2, 3, 4]
print(numbers[:3])     # [1, 2, 3]
print(numbers[::2])    # [1, 3, 5]
print(numbers[::-1])   # [5, 4, 3, 2, 1] — реверс

# Методы списка
nums = [3, 1, 4, 1, 5, 9, 2]
nums.append(6)        # Добавить в конец: [3, 1, 4, 1, 5, 9, 2, 6]
nums.insert(0, 0)     # Вставить по индексу: [0, 3, 1, 4, 1, 5, 9, 2, 6]
nums.remove(1)        # Удалить первое вхождение: [0, 3, 4, 1, 5, 9, 2, 6]
popped = nums.pop(2)  # Удалить и вернуть по индексу: popped=4
nums.sort()           # Сортировка на месте: [0, 1, 2, 3, 5, 6, 9]
nums.reverse()        # Реверс на месте: [9, 6, 5, 3, 2, 1, 0]

# Длина списка
print(len(nums))  # 7

# Проверка вхождения
print(5 in nums)   # True
print(7 not in nums)  # True

# Списочные включения (list comprehension)
squares = [x ** 2 for x in range(1, 6)]       # [1, 4, 9, 16, 25]
evens = [x for x in range(20) if x % 2 == 0]   # [0, 2, 4, ..., 18]
matrix = [[i * 3 + j for j in range(3)] for i in range(3)]
# [[0, 1, 2], [3, 4, 5], [6, 7, 8]]
```

### Словари [(dict)](https://pythonworld.ru/tipy-dannyx-v-python/slovari-dict-funkcii-i-metody-slovarej.html)

Словарь — *неупорядоченная* коллекция пар «ключ-значение». Ключи уникальны и должны быть [хешируемыми](https://youngjunior.ru/python/interviews/13399).

```python
# Создание словарей
person = {"name": "Анна", "age": 25, "city": "Москва"}
empty = {}
empty2 = dict()
empty3 = dict(name="Иван", age=30)

# Доступ к элементам
print(person["name"])       # Анна
print(person.get("phone"))  # None (без ошибки)
print(person.get("phone", "не указан"))  # не указан

# Изменение и добавление
person["age"] = 26
person["email"] = "anna@example.com"

# Удаление
del person["city"]
removed = person.pop("age")  # удалит и вернёт значение

# Итерация по словарю
for key in person:
    print(f"{key}: {person[key]}")

for key, value in person.items():
    print(f"{key} → {value}")

for key in person.keys():
    print(key)

for value in person.values():
    print(value)

# Вложенные словари
students = {
    "Анна": {"grade": 5, "subject": "математика"},
    "Пётр": {"grade": 4, "subject": "физика"},
}
print(students["Анна"]["grade"])  # 5

# Проверка ключа
print("name" in person)  # True

# Словарные включения (dict comprehension)
squares_dict = {x: x ** 2 for x in range(1, 6)}
# {1: 1, 2: 4, 3: 9, 4: 16, 5: 25}
freq = {word: count for word, count in [("cat", 3), ("dog", 4)]}
# {'cat': 3, 'dog': 4}
```

### Кортежи [(tuple)](https://pythonworld.ru/tipy-dannyx-v-python/kortezhi-tuple.html)

Кортеж — *упорядоченная* неизменяемая коллекция. Используется для группировки связанных данных.

```python
# Создание кортежей
point = (3, 5)
colors = ("red", "green", "blue")
single = (42,)  # Запятая обязательна! (42) — это просто число 42
mixed = (1, "hello", True)

# Индексация и срезы (как у списков)
print(colors[0])    # red
print(colors[-1])   # blue
print(colors[1:])   # ('green', 'blue')

# Кортежи можно использовать как ключи словаря (так как они хешируемы)
locations = {
    point: "начало координат смещено",
    (0, 0): "origin",
}
print(locations[(0, 0)])  # origin

# Распаковка кортежей
a, b, c = colors
print(a, b, c)  # red green blue

x, y = point
print(f"x={x}, y={y}")  # x=3, y=5

# Распаковка с *
first, *rest = (1, 2, 3, 4, 5)
print(first)  # 1
print(rest)   # [2, 3, 4, 5]

# Изменение через конвертацию
colors_list = list(colors)
colors_list[0] = "yellow"
colors = tuple(colors_list)
print(colors)  # ('yellow', 'green', 'blue')

# Методы кортежей
nums = (1, 2, 3, 2, 4, 2)
print(nums.count(2))  # 3 — количество вхождений
print(nums.index(4))  # 4 — индекс первого вхождения
```

### Множества [(set)](https://pythonworld.ru/tipy-dannyx-v-python/mnozhestva-set-i-frozenset.html)

Множество — неупорядоченная коллекция уникальных элементов. Поддерживает математические операции над множествами.

```python
# Создание множеств
fruits = {"apple", "banana", "cherry"}
numbers = set([1, 2, 3, 4, 5, 4, 3])  # {1, 2, 3, 4, 5} — дубликаты удалены
empty = set()  # Пустое множество — только через set(), {} это dict!

# Добавление и удаление
fruits.add("date")
fruits.update(["elderberry", "fig"])
fruits.remove("apple")     # KeyError если элемента нет
fruits.discard("apple")    # без ошибки если нет
popped = fruits.pop()      # удаляет случайный элемент

# Операции над множествами
a = {1, 2, 3, 4}
b = {3, 4, 5, 6}

print(a | b)   # {1, 2, 3, 4, 5, 6} — объединение
print(a & b)   # {3, 4} — пересечение
print(a - b)   # {1, 2} — разность
print(a ^ b)   # {1, 2, 5, 6} — симметрическая разность

# Проверки
print(3 in a)      # True
print(10 not in a) # True

# Подмножества и надмножества
print({1, 2}.issubset({1, 2, 3}))      # True
print({1, 2, 3, 4}.issuperset({1, 2})) # True

# Множественные включения (set comprehension)
unique_lengths = {len(word) for word in ["hello", "hi", "world", "python"]}
# {2, 5, 6}
```

### Цикл [for](https://pyplanet.ru/article/for.html)

Цикл for перебирает элементы любой итерируемой коллекции.

```python
# Базовый цикл for
fruits = ["яблоко", "банан", "вишня"]
for fruit in fruits:
    print(f"Я люблю {fruit}")

# range() — генератор чисел
for i in range(5):         # 0, 1, 2, 3, 4
    print(i, end=" ")
print()

for i in range(2, 8):      # 2, 3, 4, 5, 6, 7
    print(i, end=" ")
print()

for i in range(0, 10, 2):  # 0, 2, 4, 6, 8
    print(i, end=" ")
print()

# enumerate() — индекс и значение
for i, fruit in enumerate(fruits):
    print(f"{i}: {fruit}")
# 0: яблоко
# 1: банан
# 2: вишня

# zip() — параллельная итерация по нескольким коллекциям
names = ["Анна", "Пётр", "Мария"]
ages = [25, 30, 28]
for name, age in zip(names, ages):
    print(f"{name} — {age} лет")

# Итерация по словарю
scores = {"Анна": 95, "Пётр": 87, "Мария": 92}
for name, score in scores.items():
    print(f"{name}: {score}")

# Вложенные циклы
for i in range(1, 4):
    for j in range(1, 4):
        print(f"{i}×{j} = {i*j}", end="  ")
    print()

# break — выход из цикла
for i in range(10):
    if i == 5:
        break
    print(i, end=" ")
print()  # 0 1 2 3 4

# continue — пропуск итерации
for i in range(10):
    if i % 2 == 0:
        continue
    print(i, end=" ")
print()  # 1 3 5 7 9
```

### Цикл [while](https://pyplanet.ru/article/while.html)

Цикл while выполняется, пока условие истинно.

```python
# Базовый цикл while
count = 0
while count < 5:
    print(count, end=" ")
    count += 1
print()  # 0 1 2 3 4

# break и continue с while
i = 0
while True:
    i += 1
    if i % 2 == 0:
        continue
    print(i, end=" ")
    if i >= 10:
        break
print()  # 1 3 5 7 9

# else после while — выполняется если цикл не прерван break
n = 20
factor = 2
while factor * factor <= n:
    if n % factor == 0:
        print(f"{n} делится на {factor}")
        break
    factor += 1
else:
    print(f"{n} — простое число")

# Бесконечный цикл с условием выхода
password = ""
while password != "secret":
    password = input("Введите пароль: ")
    if password != "secret":
        print("Неверно!")
print("Доступ разрешён!")
```

### Функции преобразования типов

```python
# list() — в список
t = (1, 2, 3)
s = list(t)  # [1, 2, 3]

# tuple() — в кортеж
l = [4, 5, 6]
t = tuple(l)  # (4, 5, 6)

# set() — в множество
l = [1, 2, 2, 3, 3, 3]
s = set(l)  # {1, 2, 3}

# dict() — из пар ключ-значение
pairs = [("a", 1), ("b", 2), ("c", 3)]
d = dict(pairs)  # {'a': 1, 'b': 2, 'c': 3}

# zip() — объединение списков в пары
keys = ["name", "age", "city"]
values = ["Анна", 25, "Москва"]
d = dict(zip(keys, values))
# {'name': 'Анна', 'age': 25, 'city': 'Москва'}

# sorted() — сортировка (возвращает новый список)
unsorted = [3, 1, 4, 1, 5, 9, 2, 6]
print(sorted(unsorted))       # [1, 1, 2, 3, 4, 5, 6, 9]
print(sorted(unsorted, reverse=True))  # [9, 6, 5, 4, 3, 2, 1, 1]

# enumerate() — пара (индекс, значение)
items = ["a", "b", "c"]
for idx, val in enumerate(items):
    print(f"{idx}: {val}")

# reversed() — обратный порядок
for x in reversed([1, 2, 3]):
    print(x, end=" ")
print()  # 3 2 1

# iter() и next() — ручная итерация
it = iter([10, 20, 30])
print(next(it))  # 10
print(next(it))  # 20
print(next(it))  # 30
```

---

## 📁 Материалы и методы

- Среда выполнения — Jupyter Notebook (доступен через JupyterHub)
- Язык программирования — [Python](https://www.python.org/)
- Основные библиотеки:
  - [numpy](https://numpy.org/) — для числовых вычислений

---

## 🧪 Программа работы

---

### ⚙️ Настройка среды

**Откройте JupyterHub**: `http://<server-ip>:8000`, войдите под своей учётной записью.

В левой части Jupyter Lab перейдите (предположим, Вы находитесь в своем корневом каталоге `~`) в `project` -> `reports`

Создайте новый каталог `Pr_2`

Создайте новый Jupyter Notebook: **File → New → Notebook → Python 3 (ipykernel)**.

Сохраните новый Jupyter Notebook под именем `Pr_2_report.ipynb` (в `~/project/reports/Pr_2`)

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

### 📌 Практика 1: Списки (list)

**Задание 1.** Создан список из 10 случайных чисел от 1 до 100. Найдите и выведите на экран максимальный, минимальный элемент и их индексы.

```python
import random

numbers = [random.randint(1, 100) for _ in range(10)]
print(f"Список: {numbers}")
```

<!-- ANSWER
```python
print(f"Максимум: {max(numbers)} (индекс {numbers.index(max(numbers))})")
print(f"Минимум: {min(numbers)} (индекс {numbers.index(min(numbers))})")
```
-->

**Задание 2.** Дан список слов. Отфильтруйте те, длина которых больше 4 символов, и отсортируйте результат по алфавиту.

Список слов:
```python
words = ["банан", "яблоко", "вишня", "груша", "слива", "абрикос", "персик"]
```

<!-- ANSWER
```python
long_words = sorted([w for w in words if len(w) > 4])
print(long_words)
```
-->

---

### 📌 Практика 2: Словари (dict)

**Задание 3.** Дан словарь, где ключ — название города, значение — список температур за 5 дней. Найдите город с максимальной средней температурой.
```python
temperatures = {
    "Москва": [22, 24, 21, 23, 25],
    "Санкт-Петербург": [18, 19, 17, 20, 18],
    "Казань": [25, 27, 26, 24, 28],
}
```

<!-- ANSWER
```python
best_city = None
best_avg = -1
for city, temps in temperatures.items():
    avg = sum(temps) / len(temps)
    if best_city is None or avg > best_avg:
        best_city = city
        best_avg = avg

print(f"Самый тёплый город: {best_city} (средняя {best_avg:.1f}°C)")
```
-->

**Задание 4.** Дан словарь с оценками студентов. Посчитайте средний балл каждого студента и выведите рейтинг (по убыванию).

```python
grades = {
    "Анна": [5, 4, 5, 5, 4],
    "Пётр": [4, 4, 3, 4, 4],
    "Мария": [5, 5, 5, 5, 5],
    "Иван": [3, 4, 3, 4, 3],
}
```

<!-- ANSWER
```python
averages = [(name, sum(student_grades) / len(student_grades)) for name, student_grades in grades.items()]
averages.sort(key=lambda item: item[1], reverse=True)
for name, avg in averages:
    print(f"{name}: {avg:.2f}")
```
-->

**Задание 5.** Решите задачу: дан список строк. Создайте словарь, где ключ — длина слова, значение — список слов такой длины. Отсортируйте по длине.

```python
words = ["hi", "hello", "world", "python", "a", "code", "programming", "go"]
```

<!-- ANSWER
```python
groups = {}
for word in words:
    length = len(word)
    if length not in groups:
        groups[length] = []
    groups[length].append(word)

result = {length: groups[length] for length in sorted(groups)}
for length, word_list in result.items():
    print(f"{length}: {word_list}")
```
-->

**Задание 6.** Посчитайте по тексту: количество слов, уникальных слов, среднюю длину слова, наиболее частое слово.

```python
text = "python is great python is fun python is powerful and python is easy"
```

<!-- ANSWER
```python
words = text.lower().split()

freq = {}
for word in words:
    freq[word] = freq.get(word, 0) + 1

most_common = max(freq, key=freq.get)

stats = {
    "total_words": len(words),
    "unique_words": len(freq),
    "avg_length": sum(len(w) for w in words) / len(words),
    "most_common": most_common,
    "most_common_count": freq[most_common],
}

for key, value in stats.items():
    print(f"{key}: {value}")
```
-->

---

### 📌 Практика 3: Кортежи и множества

**Задание 7.** Дан список кортежей с данными о студентах: `(имя, возраст, курс)`. Отсортируйте по возрасту, затем по имени.

```python
students = [("Мария", 20, 2), ("Анна", 19, 1), ("Пётр", 21, 3), ("Иван", 19, 2)]
```

<!-- ANSWER
```python
sorted_students = sorted(students, key=lambda s: (s[1], s[0]))
for name, age, course in sorted_students:
    print(f"{name}, {age} лет, курс {course}")
```
-->

**Задание 8.** Найдите общие и уникальные элементы двух множеств слов.

```python
text1 = "python is great and python is fun".split()
text2 = "python is powerful and easy to learn".split()

set1 = set(text1)
set2 = set(text2)
```

<!-- ANSWER
```python
print(f"Уникальные для текста 1: {set1 - set2}")
print(f"Уникальные для текста 2: {set2 - set1}")
print(f"Общие слова: {set1 & set2}")
print(f"Все слова: {set1 | set2}")
```
-->

---

### 📌 Практика 4: Цикл for

**Задание 9.** Выведите таблицу умножения 10×10, используя вложенные циклы for.

<!-- ANSWER
```python
for i in range(1, 11):
    row = [f"{i*j:3d}" for j in range(1, 11)]
    print(" | ".join(row))
```
-->

**Задание 10.** Используйте `enumerate()` и `zip()` для анализа данных. Дан список оценок по предметам для каждого студента. Найдите средний балл по каждому предмету.

```python
students = {
    "Анна": {"математика": 5, "физика": 4, "информатика": 5},
    "Пётр": {"математика": 4, "физика": 5, "информатика": 4},
    "Мария": {"математика": 3, "физика": 4, "информатика": 5},
}
```

<!-- ANSWER
```python
subjects = list(students["Анна"].keys())
for subject in subjects:
    scores = [data[subject] for data in students.values()]
    avg = sum(scores) / len(scores)
    print(f"{subject}: {avg:.2f}")
```
-->

---

### 📌 Практика 5: Цикл while

**Задание 11.** Напишите программу-калькулятор, которая читает выражения в формате `операнд1 оператор операнд2` до ввода "exit".

<!-- ANSWER
```python
while True:
    expr = input("Введите выражение (или 'exit'): ").strip()
    if expr.lower() == "exit":
        print("Завершение работы.")
        break
    parts = expr.split()
    if len(parts) != 3:
        print("Формат: операнд оператор операнд")
        continue
    try:
        a = float(parts[0])
        op = parts[1]
        b = float(parts[2])
        if op == "+":
            print(f"Результат: {a + b}")
        elif op == "-":
            print(f"Результат: {a - b}")
        elif op == "*":
            print(f"Результат: {a * b}")
        elif op == "/":
            if b == 0:
                print("Деление на ноль!")
            else:
                print(f"Результат: {a / b}")
        else:
            print("Неизвестный оператор")
    except ValueError:
        print("Некорректные числа")
```
-->

---

## 📌 Отчёт о выполненной работе после выполнения заданий / завершения занятия

1. Добавьте в конец Jupyter Notebook `Pr_2_report.ipynb` Markdown-ячейку с ответами на контрольные вопросы из раздела [«Контрольные вопросы»](Pr_2.md#контрольные-вопросы)
   - Тип ячейки выбирается в верхней части окна Jupyter Notebook'а из выпадающего списка, где по умолчанию стоит значение `Code`
3. Сохраните Jupyter Notebook
4. Загрузите файл в свой репозиторий в GitLab:
   - В левом окне Jupyter Lab (файловом менеджере) перейдите в каталог `project` (поднимитесь на два уровня вверх: из `Pr_2` в `reports` -> `project`)
   - Создайте новую вкладку типа `Terminal` (File -> New -> Terminal)
   - Введите

```bash
git add .
git commit -m "Pr_2 notebook report"
git push
```

> ⏳ Оценка запустится автоматически в GitLab CI. Результат появится в разделе **CI/CD → Pipelines**.

---

## Контрольные вопросы

1. Чем `list`, `tuple` и `set` отличаются по изменяемости и допустимости повторяющихся элементов?
2. Как в Python используются индексация, срезы и методы списков для чтения и изменения коллекции?
3. Почему словарь удобен для хранения пар «ключ — значение» и как безопасно получить значение по ключу?
4. В каких случаях применяются `for` + `range`, `enumerate` и `zip`?
5. Как работают `break`, `continue` и блок `else` при циклах `for`/`while`?
