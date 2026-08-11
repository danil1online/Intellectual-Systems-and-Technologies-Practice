# Практическая работа №2
# Практическая работа №2: Знакомство с Python. Структуры данных и циклы

---

## 🎯 Цель работы

Приобрести практические навыки работы с основными структурами данных Python (списки, словари, кортежи, множества) и организации циклов (for, while) с управляющими конструкциями.

---

## ⚠️ Важно

Это работа в формате **Notebook-based**. Вам будет доступен **ИИ-ментор** (`%%ask_mentor`). Все запросы логируются.

---

## 📚 Основные идеи и теоретические основы.

### Списки (list)

Список — упорядоченная изменяемая коллекция элементов. Элементы обращаются по индексу (начиная с 0).

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

### Словари (dict)

Словарь — неупорядоченная (до Python 3.7 — произвольный порядок, с 3.7 — insertion order) коллекция пар «ключ-значение». Ключи уникальны и должны быть хешируемыми.

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
freq = {word: len(words) for word, words in [("cat", 3), ("dog", 4)]}
```

### Кортежи (tuple)

Кортеж — упорядоченная неизменяемая коллекция. Используется для группировки связанных данных.

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

### Множества (set)

Множество — неупорядоченная коллекция уникальных элементов. Поддерживает матемические операции над множествами.

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

### Цикл for

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

### Цикл while

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

Создайте новый Jupyter Notebook: **File → New → Notebook → Python 3**.

Первый блок кода — проверка версии Python:

```python
import sys
print(f"Python version: {sys.version}")
```

---

### 📌 Практика 1: Списки (list)

**Задание 1.** Создайте список из 10 случайных чисел от 1 до 100. Найдите максимальный, минимальный элемент и их индексы.

```python
import random

numbers = [random.randint(1, 100) for _ in range(10)]
print(f"Список: {numbers}")
print(f"Максимум: {max(numbers)} (индекс {numbers.index(max(numbers))})")
print(f"Минимум: {min(numbers)} (индекс {numbers.index(min(numbers))})")
```

**Задание 2.** Дан список слов. Отфильтруйте те, длина которых больше 4 символов, и отсортируйте результат по алфавиту.

```python
words = ["банан", "яблоко", "вишня", "груша", "слива", "абрикос", "персик"]
long_words = sorted([w for w in words if len(w) > 4])
print(long_words)
```

**Задание 3.** Напишите функцию `matrix_transpose(matrix)`, которая транспонирует матрицу (меняет строки и столбцы местами).

```python
def matrix_transpose(matrix):
    return [[matrix[r][c] for r in range(len(matrix))] for c in range(len(matrix[0]))]

matrix = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9]
]
print("Исходная:")
for row in matrix:
    print(row)
print("Транспонированная:")
for row in matrix_transpose(matrix):
    print(row)
```

**Задание 4.** Напишите функцию `unique_elements(lst)`, которая возвращает список уникальных элементов (без повторов), сохраняя порядок.

```python
def unique_elements(lst):
    seen = []
    for item in lst:
        if item not in seen:
            seen.append(item)
    return seen

data = [1, 2, 3, 2, 1, 4, 5, 3, 6, 5]
print(unique_elements(data))  # [1, 2, 3, 4, 5, 6]
```

---

### 📌 Практика 2: Словари (dict)

**Задание 5.** Создайте словарь, где ключ — название города, значение — список температур за 5 дней. Найдите город с максимальной средней температурой.

```python
temperatures = {
    "Москва": [22, 24, 21, 23, 25],
    "Санкт-Петербург": [18, 19, 17, 20, 18],
    "Казань": [25, 27, 26, 24, 28],
}

def avg_temp(city, temps):
    return sum(temps) / len(temps)

best_city = max(temperatures, key=lambda city: avg_temp(city, temperatures[city]))
print(f"Самый тёплый город: {best_city} (средняя {avg_temp(best_city, temperatures[best_city]):.1f}°C)")
```

**Задание 6.** Напишите функцию `invert_dict(d)`, которая меняет местами ключи и значения словаря.

```python
def invert_dict(d):
    return {v: k for k, v in d.items()}

original = {"a": 1, "b": 2, "c": 3}
inverted = invert_dict(original)
print(f"Оригинал: {original}")
print(f"Инвертированный: {inverted}")
```

**Задание 7.** Дан словарь с оценками студентов. Посчитайте средний балл каждого студента и выведите рейтинг (по убыванию).

```python
grades = {
    "Анна": [5, 4, 5, 5, 4],
    "Пётр": [4, 4, 3, 4, 4],
    "Мария": [5, 5, 5, 5, 5],
    "Иван": [3, 4, 3, 4, 3],
}

def average(lst):
    return sum(lst) / len(lst)

rating = sorted(grades.items(), key=lambda x: average(x[1]), reverse=True)
for name, g in rating:
    print(f"{name}: {average(g):.2f}")
```

**Задание 8.** Объедините два словаря, суммируя значения одинаковых ключей.

```python
def merge_dicts(d1, d2):
    result = {}
    for k, v in d1.items():
        result[k] = result.get(k, 0) + v
    for k, v in d2.items():
        result[k] = result.get(k, 0) + v
    return result

dict_a = {"a": 1, "b": 2, "c": 3}
dict_b = {"b": 5, "c": 7, "d": 9}
print(merge_dicts(dict_a, dict_b))  # {'a': 1, 'b': 7, 'c': 10, 'd': 9}
```

---

### 📌 Практика 3: Кортежи и множества

**Задание 9.** Напишите функцию `swap(a, b)`, которая меняет местами две переменные, используя кортежи.

```python
def swap(a, b):
    return b, a

x, y = 10, 20
x, y = swap(x, y)
print(f"x={x}, y={y}")  # x=20, y=10
```

**Задание 10.** Дан список кортежей с данными о студентах: `(имя, возраст, курс)`. Отсортируйте по возрасту, затем по имени.

```python
students = [("Мария", 20, 2), ("Анна", 19, 1), ("Пётр", 21, 3), ("Иван", 19, 2)]
sorted_students = sorted(students, key=lambda s: (s[1], s[0]))
for name, age, course in sorted_students:
    print(f"{name}, {age} лет, курс {course}")
```

**Задание 11.** Найдите общие и уникальные элементы двух множеств слов.

```python
text1 = "python is great and python is fun".split()
text2 = "python is powerful and easy to learn".split()

set1 = set(text1)
set2 = set(text2)

print(f"Уникальные для текста 1: {set1 - set2}")
print(f"Уникальные для текста 2: {set2 - set1}")
print(f"Общие слова: {set1 & set2}")
print(f"Все слова: {set1 | set2}")
```

**Задание 12.** Напишите функцию `word_index(text)`, которая создаёт словарь, где ключ — слово, значение — множество позиций в тексте.

```python
def word_index(text):
    words = text.lower().split()
    index = {}
    for pos, word in enumerate(words):
        if word not in index:
            index[word] = set()
        index[word].add(pos)
    return index

text = "python is great and python is fun and python is powerful"
print(word_index(text))
# {'python': {0, 5, 11}, 'is': {1, 6, 12}, 'great': {2}, ...}
```

---

### 📌 Практика 4: Цикл for

**Задание 13.** Выведите таблицу умножения 10×10, используя вложенные циклы for.

```python
for i in range(1, 11):
    row = [f"{i*j:3d}" for j in range(1, 11)]
    print(" | ".join(row))
```

**Задание 14.** Напишите функцию `flatten(nested_list)`, которая «сплющивает» вложенный список любой глубины.

```python
def flatten(nested_list):
    result = []
    for item in nested_list:
        if isinstance(item, list):
            result.extend(flatten(item))
        else:
            result.append(item)
    return result

nested = [1, [2, [3, [4, [5]]]], [6, 7], 8]
print(flatten(nested))  # [1, 2, 3, 4, 5, 6, 7, 8]
```

**Задание 15.** Используйте `enumerate()` и `zip()` для анализа данных. Дан список оценок по предметам для каждого студента. Найдите средний балл по каждому предмету.

```python
students = {
    "Анна": {"математика": 5, "физика": 4, "информатика": 5},
    "Пётр": {"математика": 4, "физика": 5, "информатика": 4},
    "Мария": {"математика": 3, "физика": 4, "информатика": 5},
}

subjects = list(students["Анна"].keys())
for subject in subjects:
    scores = [data[subject] for data in students.values()]
    avg = sum(scores) / len(scores)
    print(f"{subject}: {avg:.2f}")
```

**Задание 16.** Напишите функцию `find_duplicates(lst)`, которая возвращает список элементов, встречающихся более одного раза.

```python
def find_duplicates(lst):
    seen = set()
    duplicates = set()
    for item in lst:
        if item in seen:
            duplicates.add(item)
        else:
            seen.add(item)
    return list(duplicates)

data = [1, 2, 3, 2, 4, 5, 3, 6, 7, 5, 8]
print(find_duplicates(data))  # [2, 3, 5]
```

---

### 📌 Практика 5: Цикл while

**Задание 17.** Напишите функцию `reverse_number(n)`, которая переворачивает число (например, 12345 → 54321).

```python
def reverse_number(n):
    result = 0
    while n > 0:
        result = result * 10 + n % 10
        n //= 10
    return result

print(reverse_number(12345))  # 54321
```

**Задание 18.** Напишите функцию `gcd(a, b)`, которая находит наибольший общий делитель алгоритмом Евклида через while.

```python
def gcd(a, b):
    while b != 0:
        a, b = b, a % b
    return a

print(f"GCD(48, 18) = {gcd(48, 18)}")   # 6
print(f"GCD(100, 75) = {gcd(100, 75)}")  # 25
```

**Задание 19.** Генерация последовательности Коллатца. Для числа n: если чётное → n/2, если нечётное → 3n+1. Повторять пока n ≠ 1.

```python
def collatz(n):
    sequence = [n]
    while n != 1:
        if n % 2 == 0:
            n = n // 2
        else:
            n = 3 * n + 1
        sequence.append(n)
    return sequence

seq = collatz(27)
print(f"Длина последовательности: {len(seq)}")
print(f"Последние 10 элементов: {seq[-10:]}")
```

**Задание 20.** Напишите программу-калькулятор, которая читает выражения в формате `операнд1 оператор операнд2` до ввода "exit".

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

---

### 📌 Практика 6: Комбинированные задачи

**Задание 21.** Реализуйте класс `StudentRecord`, который хранит оценки студента и умеет: добавлять оценку, считать средний балл, определять оценку по шкале (5, 4, 3, 2), выводить статистику.

```python
class StudentRecord:
    def __init__(self, name):
        self.name = name
        self.grades = []
    
    def add_grade(self, grade):
        if 2 <= grade <= 5:
            self.grades.append(grade)
            return f"Оценка {grade} добавлена"
        return "Некорректная оценка (должна быть 2-5)"
    
    def average(self):
        if not self.grades:
            return 0
        return sum(self.grades) / len(self.grades)
    
    def letter_grade(self):
        avg = self.average()
        if avg >= 4.5:
            return "Отлично (5)"
        elif avg >= 3.5:
            return "Хорошо (4)"
        elif avg >= 2.5:
            return "Удовлетворительно (3)"
        else:
            return "Неудовлетворительно (2)"
    
    def stats(self):
        if not self.grades:
            return f"{self.name}: нет оценок"
        return (f"{self.name}: средний балл = {self.average():.2f}, "
                f"{self.letter_grade()}, оценок: {len(self.grades)}, "
                f"мин: {min(self.grades)}, макс: {max(self.grades)}")

student = StudentRecord("Анна")
print(student.add_grade(5))
print(student.add_grade(4))
print(student.add_grade(5))
print(student.add_grade(3))
print(student.stats())
```

**Задание 22.** Реализуйте класс `ContactBook` — телефонную книгу с возможностью добавления, поиска, удаления контактов и экспорта в словарь.

```python
class ContactBook:
    def __init__(self):
        self.contacts = {}
    
    def add(self, name, phone):
        self.contacts[name] = phone
        return f"Контакт {name} добавлен"
    
    def find(self, name):
        return self.contacts.get(name, "Контакт не найден")
    
    def remove(self, name):
        if name in self.contacts:
            del self.contacts[name]
            return f"Контакт {name} удалён"
        return "Контакт не найден"
    
    def export(self):
        return dict(self.contacts)
    
    def search(self, substring):
        results = {}
        substring = substring.lower()
        for name, phone in self.contacts.items():
            if substring in name.lower() or substring in phone:
                results[name] = phone
        return results

book = ContactBook()
book.add("Анна", "+7-999-111-11-11")
book.add("Пётр", "+7-999-222-22-22")
book.add("Мария", "+7-999-333-33-33")
book.add("Андрей", "+7-999-444-44-44")

print(book.find("Анна"))
print(book.search("анн"))
print(book.export())
```

**Задание 23.** Решите задачу: дан список строк. Создайте словарь, где ключ — длина слова, значение — список слов такой длины. Отсортируйте по длине.

```python
def group_by_length(words):
    groups = {}
    for word in words:
        length = len(word)
        if length not in groups:
            groups[length] = []
        groups[length].append(word)
    return dict(sorted(groups.items()))

words = ["hi", "hello", "world", "python", "a", "code", "programming", "go"]
result = group_by_length(words)
for length, word_list in result.items():
    print(f"{length}: {word_list}")
```

**Задание 24.** Напишите функцию `text_statistics(text)`, которая считает: количество слов, уникальных слов, среднюю длину слова, наиболее частое слово.

```python
def text_statistics(text):
    words = text.lower().split()
    if not words:
        return {}
    
    freq = {}
    for word in words:
        freq[word] = freq.get(word, 0) + 1
    
    most_common = max(freq, key=freq.get)
    
    return {
        "total_words": len(words),
        "unique_words": len(freq),
        "avg_length": sum(len(w) for w in words) / len(words),
        "most_common": most_common,
        "most_common_count": freq[most_common],
    }

text = "python is great python is fun python is powerful and python is easy"
stats = text_statistics(text)
for key, value in stats.items():
    print(f"{key}: {value}")
```

---

## 📌 Отчёт о выполненной работе

1. Сохраните все ячейки с выполненными заданиями в Jupyter Notebook
2. Добавьте краткие комментарии к каждому заданию
3. Сохраните ноутбук как `Pr_2_<группа>_<номер>.ipynb`
4. Загрузите файл в репозиторий `reports_<группа>_<номер>` в GitLab:

```bash
git add Pr_2_<группа>_<номер>.ipynb
git commit -m "Pr_2 notebook"
git push
```

**Финальное действие:**

Для запуска автоматической оценки создайте триггер-файл и отправьте его в репозиторий:

```bash
touch .grade-trigger
git add .grade-trigger
git commit -m "Grade trigger"
git push
```

> ⏳ Оценка запустится автоматически в GitLab CI. Результат появится в разделе **CI/CD → Pipelines**.

---

## Критерии оценки

| Критерий | Баллы |
|----------|-------|
| Списки: создание, индексация, срезы, методы, list comprehension | 2 |
| Словари: создание, доступ, итерация, dict comprehension | 2 |
| Кортежи: создание, распаковка, неизменяемость | 1 |
| Множества: создание, операции, set comprehension | 1 |
| Цикл for: range, enumerate, zip, вложенные циклы | 1.5 |
| Цикл while: break, continue, else | 1 |
| Комбинированные задачи: классы + структуры данных + циклы | 1.5 |
| **Итого** | **10** |
