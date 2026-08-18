# Практическая работа №3: Python. Функции. Классы и объекты.

---

## 🎯 Цель работы

Приобрести практические навыки работы с функциями, объектно-ориентированным программированием (классы, наследование, инкапсуляция) и пользовательскими классами в Python.

---

## ⚠️ Важно

Это работа в формате **Notebook-based**. Вам будет доступен **ИИ-ментор** (`%%ask_mentor`). Модель кроме ответа дает оценку качества вопроса.

---

## 📚 Основные идеи и теоретические основы.

### Функции

Функция — переиспользуемый блок кода с собственным именем, принимающий аргументы и возвращающий значение. Обычная [функция в python](https://pyplanet.ru/article/def-return.html) определяется с помощью инструкции def. 

Функции в python могут иметь переменное число аргументов; для этого используются термины [args, kwargs](https://pyplanet.ru/article/args-kwargs.html)

Существуют также т.н. [анонимные lambda-функции](https://pyplanet.ru/article/lambda.html)

```python
# Объявление функции
def greet(name):
    return f"Привет, {name}!"

def greet_with_greeting(greeting, name):
    return f"{greeting}, {name}!"

# Вызов функции
result = greet("Анна")
print(result)      # Привет, Анна!
print(greet_with_greeting("Здравствуйте", "Пётр"))

# Параметры по умолчанию (default arguments)
def power(x, n=2):
    return x ** n

print(power(5))    # 25
print(power(5, 3)) # 125

# *args — произвольное число позиционных аргументов
def sum_all(*args):
    return sum(args)

print(sum_all(1, 2, 3))      # 6
print(sum_all(1, 2, 3, 4, 5))  # 15

# **kwargs — произвольное число именованных аргументов
def print_kwargs(**kwargs):
    for key, value in kwargs.items():
        print(f"{key} = {value}")

print_kwargs(name="Анна", age=25, city="Москва")

# Комбинация *args и **kwargs
def mixed(*args, **kwargs):
    print(f"Позиционные: {args}")
    print(f"Именованные: {kwargs}")

mixed(1, 2, 3, a=10, b=20)

# Лямбда-функции (безымянные функции одной строки)
square = lambda x: x ** 2
print(square(4))  # 16

numbers = [1, 2, 3, 4, 5]
squared = list(map(lambda x: x ** 2, numbers))
print(squared)  # [1, 4, 9, 16, 25]

# filter и reduce
from functools import reduce
evens = list(filter(lambda x: x % 2 == 0, numbers))
product = reduce(lambda a, b: a * b, numbers)
print(f"Чётные: {evens}, произведение: {product}")

# Функции первого класса
def make_adder(n):
    def adder(x):
        return x + n
    return adder

add5 = make_adder(5)
add10 = make_adder(10)
print(add5(3))   # 8
print(add10(3))  # 13
```

### [Классы и объекты](https://pyplanet.ru/article/classes.html)

Класс — шаблон для создания объектов. Объект содержит данные (атрибуты) и поведение (методы).

```python
# Объявление класса
class Person:
    # Классовый атрибут (общий для всех объектов)
    species = "человек"

    def __init__(self, name, age):
        # self — ссылка на текущий объект
        self.name = name
        self.age = age

    # Метод класса
    def introduce(self):
        return f"Меня зовут {self.name}, мне {self.age}"

    def __str__(self):
        return f"Person({self.name}, {self.age})"

# Создание экземпляров
p1 = Person("Анна", 25)
p2 = Person("Пётр", 30)

print(p1.introduce())  # Меня зовут Анна, мне 25
print(p2.introduce())  # Меня зовут Пётр, мне 30
print(p1.species)      # человек

# Геттеры и сеттеры (property)
class Temperature:
    def __init__(self, celsius=0):
        self.celsius = celsius

    @property
    def fahrenheit(self):
        return self.celsius * 9 / 5 + 32

    @fahrenheit.setter
    def fahrenheit(self, value):
        self.celsius = (value - 32) * 5 / 9

t = Temperature(25)
print(t.fahrenheit)      # 77.0
t.fahrenheit = 100
print(t.celsius)           # 37.777...

# Магические методы (dunder methods)
class Vector:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def __add__(self, other):
        return Vector(self.x + other.x, self.y + other.y)

    def __mul__(self, scalar):
        return Vector(self.x * scalar, self.y * scalar)

    def __len__(self):
        return round((self.x ** 2 + self.y ** 2) ** 0.5)

    def __repr__(self):
        return f"Vector({self.x}, {self.y})"

v1 = Vector(3, 4)
v2 = Vector(1, 2)
print(v1 + v2)    # Vector(4, 6)
print(v1 * 2)     # Vector(6, 8)
print(len(v1))    # 5
```

### Наследование

```python
class Animal:
    def __init__(self, name):
        self.name = name

    def speak(self):
        return "..."

    def __str__(self):
        return f"{self.__class__.__name__}: {self.name}"

class Dog(Animal):
    def speak(self):
        return "Гав!"

    def fetch(self):
        return f"{self.name} приносит мячик"

class Cat(Animal):
    def speak(self):
        return "Мяу!"

# Множественное наследование
class Swimming:
    def swim(self):
        return f"{self.name} плавает"

class Flying:
    def fly(self):
        return f"{self.name} летает"

class Duck(Animal, Swimming, Flying):
    def speak(self):
        return "Кря!"

dog = Dog("Рекс")
cat = Cat("Мурка")
duck = Duck("Кряква")

print(dog.speak())   # Гав!
print(cat.speak())   # Мяу!
print(duck.speak())  # Кря!
print(dog.fetch())   # Рекс приносит мячик
print(duck.swim())   # Кряква плавает
print(duck.fly())    # Кряква летает

# MRO (Method Resolution Order)
print(Duck.mro())
```

### Инкапсуляция

```python
class BankAccount:
    def __init__(self, initial_balance=0):
        # Публичный атрибут
        self.owner = "Владелец"
        # "Защищённый" атрибут (конвенция — один underscore)
        self._balance = initial_balance
        # "Приватный" атрибут (двойной underscore — имя-модификация)
        self.__pin = 1234

    # Публичные методы для доступа к приватным данным
    def deposit(self, amount):
        if amount > 0:
            self._balance += amount
            print(f"Внесено: {amount}. Баланс: {self._balance}")
        else:
            print("Сумма должна быть положительной")

    def withdraw(self, amount, pin):
        if pin != self.__pin:
            print("Неверный PIN")
            return
        if amount > self._balance:
            print("Недостаточно средств")
        else:
            self._balance -= amount
            print(f"Снято: {amount}. Баланс: {self._balance}")

    def get_balance(self):
        return self._balance

acc = BankAccount(1000)
acc.deposit(500)
acc.withdraw(200, 1234)
acc.withdraw(5000, 1234)
acc.withdraw(100, 0000)  # Неверный PIN
print(acc.get_balance())
```

### Работа с файлами

```python
# Запись в файл
with open("example.txt", "w", encoding="utf-8") as f:
    f.write("Строка 1\n")
    f.write("Строка 2\n")
    f.writelines(["Строка 3\n", "Строка 4\n"])

# Чтение из файла
with open("example.txt", "r", encoding="utf-8") as f:
    content = f.read()
    print(content)

# Чтение построчно
with open("example.txt", "r", encoding="utf-8") as f:
    for i, line in enumerate(f, 1):
        print(f"Линия {i}: {line.strip()}")

# JSON
import json

data = {"name": "Анна", "age": 25, "skills": ["Python", "Data Science"]}
with open("data.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

with open("data.json", "r", encoding="utf-8") as f:
    loaded = json.load(f)
print(loaded)
```

---

## 📁 Материалы и методы

- Среда выполнения — Jupyter Notebook (доступен через JupyterHub)
- Язык программирования — [Python](https://www.python.org/)
- Основные библиотеки:
  - [numpy](https://numpy.org/) — для числовых вычислений
  - [pandas](https://pandas.pydata.org/) — для работы с табличными данными

---

## 🧪 Программа работы

---

### ⚙️ Настройка среды

**Откройте JupyterHub**: `http://<server-ip>:8000`, войдите под своей учётной записью.

В левой части Jupyter Lab перейдите (предположим, Вы находитесь в своем корневом каталоге `~`) в `project` -> `reports`

Создайте новый каталог `Pr_3`

Создайте новый Jupyter Notebook: **File → New → Notebook → Python 3 (ipykernel)**.

Сохраните новый Jupyter Notebook под именем `Pr_3_report.ipynb` (в `~/project/reports/Pr_3`)

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

### 📌 Практика 1: Функции и параметры

**Задание 1.** Реализуйте функцию `fibonacci(n)`, которая возвращает список первых `n` чисел Фибоначчи.

<!-- ANSWER
```python
def fibonacci(n):
    a, b = 0, 1
    result = []
    for _ in range(n):
        result.append(a)
        a, b = b, a + b
    return result

print(fibonacci(10))
```
-->

**Задание 2.** Реализуйте функцию `flatten_list(lst)`, которая расправляет вложенный список (любой глубины) в плоский список.

<!-- ANSWER
```python
def flatten_list(lst):
    result = []
    for element in lst:
        if isinstance(element, list):
            result.extend(flatten_list(element))
        else:
            result.append(element)
    return result

data = [1, [2, 3], [4, [5, 6]], 7]
print(flatten_list(data))
```
-->

**Задание 3.** Реализуйте функцию `word_freq(text)`, которая возвращает словарь частот слов в тексте (с учётом регистра).

<!-- ANSWER
```python
def word_freq(text):
    words = text.lower().split()
    freq = {}
    for word in words:
        freq[word] = freq.get(word, 0) + 1
    return freq

text = "Python is great and Python is fun"
for word, count in word_freq(text).items():
    print(f"{word}: {count}")
```
-->

**Задание 4.** Реализуйте обработку списка чисел с использованием [map()](https://pyplanet.ru/article/map.html), [filter()](https://pyplanet.ru/article/filter.html) и [reduce()](https://pyplanet.ru/article/functoolsreduce.html) (из `functools`). Вычислите квадраты, чётные числа и сумму.

```python
№Импорт библиотеки
from functools import reduce
# Список чисел
numbers = list(range(1, 11))
```

<!-- ANSWER
```python
squares = list(map(lambda x: x ** 2, numbers))
evens = list(filter(lambda x: x % 2 == 0, numbers))
total = reduce(lambda a, b: a + b, numbers)

print(f"Квадраты: {squares}")
print(f"Чётные: {evens}")
print(f"Сумма: {total}")
```
-->

**Задание 5.** Напишите функцию `matrix_transpose(matrix)`, которая транспонирует матрицу (меняет строки и столбцы местами).

Исходная матрица 
```python
matrix = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
```

<!-- ANSWER
```python
def matrix_transpose(matrix_):
    if not matrix_:
        return []
    rows = len(matrix_)
    cols = len(matrix_[0])
    return [[matrix_[r][c] for r in range(rows)] for c in range(cols)]

for row in matrix_transpose(matrix):
    print(row)
```
-->

**Задание 6.** Напишите функцию `unique_elements(lst)`, которая возвращает список уникальных элементов, сохраняя порядок их первого появления.

Исходные данные
```python
data = [1, 2, 2, 3, 4, 3, 5, 1]
```

<!-- ANSWER
```python
def unique_elements(lst):
    return list(dict.fromkeys(lst))

print(unique_elements(data))
print(dict.fromkeys(data))  # словарь — ещё один способ
```
-->

**Задание 7.** Напишите функцию `swap(a, b)`, которая меняет местами значения двух переменных и возвращает новый кортеж.

Исходный кортеж
```python
x, y = 10, 20
```

<!-- ANSWER
```python
def swap(a, b):
    a, b = b, a
    return a, b

x, y = swap(x, y)
print(x, y)
```
-->

**Задание 8.** Напишите функцию `reverse_number(n)`, которая "разворачивает" число (обратный порядок цифр). Обработайте отрицательные числа.

<!-- ANSWER
```python
def reverse_number(n):
    if n >= 0:
        return int(str(n)[::-1])
    return -int(str(-n)[::-1])

print(reverse_number(12300))
print(reverse_number(-456))
```
-->

**Задание 9.** Реализуйте [алгоритм Евклида для вычисления наибольшего общего делителя (НОД)](https://younglinux.info/algorithm/euclidean): `gcd(a, b)`.

<!-- ANSWER
```python
def gcd(a, b):
    while b:
        a, b = b, a % b
    return abs(a)

print(gcd(48, 18))
```
-->

**Задание 10.** Реализуйте [гипотезу Коллатца](https://habr.com/ru/articles/597935/): `collatz(n)` — количество шагов до единицы.

<!-- ANSWER
```python
def collatz(n):
    steps = 0
    while n != 1:
        if n % 2 == 0:
            n = n // 2
        else:
            n = 3 * n + 1
        steps += 1
    return steps

print(collatz(27))
```
-->

---

### 📌 Практика 2: Функции со структурами данных

**Задание 11.** Реализуйте функцию `find_duplicates(lst)`, которая возвращает список всех дубликатов в списке.

Исходный список
```python
data = [1, 2, 3, 2, 4, 5, 3, 6]
```

<!-- ANSWER
```python
def find_duplicates(lst):
    seen = set()
    duplicates = set()
    for item in lst:
        if item in seen:
            duplicates.add(item)
        seen.add(item)
    return list(duplicates)

print(find_duplicates(data))
```
-->

**Задание 12.** Реализуйте функцию `invert_dict(d)`, которая инвертирует словарь (значения становятся ключами, а ключи — списками значений).

Исходный словарь
```python
d = {"a": 1, "b": 1, "c": 2, "d": 2, "e": 3}
```

<!-- ANSWER
```python
def invert_dict(d):
    inverted = {}
    for key, value in d.items():
        inverted.setdefault(value, []).append(key)
    return inverted
    
for value, keys in invert_dict(d).items():
    print(f"{value}: {keys}")
```
-->

**Задание 13.** Реализуйте функцию `merge_dicts(*dicts)`, которая объединяет несколько словарей с суммированием значений для общих ключей.

Исходные словари:
```python
d1 = {"a": 1, "b": 2, "c": 3}
d2 = {"b": 5, "c": 7, "d": 4}
```

<!-- ANSWER
```python
def merge_dicts(*dicts):
    result = {}
    for d in dicts:
        for key, value in d.items():
            result[key] = result.get(key, 0) + value
    return result

print(merge_dicts(d1, d2))
```
-->

**Задание 14.** Реализуйте функцию `word_index(text)`, которая строит инвертированный индекс: словарь word → список позиций в тексте.

Исходный текст
```python
text = "to be or not to be thats the question to be"
```

<!-- ANSWER
```python
def word_index(text):
    words = text.lower().split()
    index = {}
    for i, word in enumerate(words):
        index.setdefault(word, []).append(i)
    return index

for word, positions in sorted(word_index(text).items()):
    print(f"{word}: {positions}")
```
-->

---

### 📌 Практика 3: Классы и наследование

**Задание 15.** Реализуйте класс `BankAccount` с методами `deposit(amount)`, `withdraw(amount)`, реализующими проверку на отрицательные значения и недостаточный баланс.

<!-- ANSWER
```python
class BankAccount:
    def __init__(self, owner, balance=0):
        self.owner = owner
        self.balance = balance

    def deposit(self, amount):
        if amount > 0:
            self.balance += amount
            print(f"Внесено: {amount}. Баланс: {self.balance}")
        else:
            print("Сумма должна быть положительной")

    def withdraw(self, amount):
        if amount > self.balance:
            print("Недостаточно средств")
        else:
            self.balance -= amount
            print(f"Снято: {amount}. Баланс: {self.balance}")

    def __str__(self):
        return f"{self.owner}: {self.balance} руб."

acc = BankAccount("Анна", 1000)
acc.deposit(500)
acc.withdraw(200)
acc.withdraw(5000)
print(acc)
```
-->

**Задание 16.** Создайте класс `SavingsAccount` с наследованием от `BankAccount` и добавленной функцией начисления процента по ставке.

<!-- ANSWER
```python
class BankAccount:
    def __init__(self, owner, balance=0):
        self.owner = owner
        self.balance = balance

    def deposit(self, amount):
        if amount > 0:
            self.balance += amount
            print(f"Внесено: {amount}. Баланс: {self.balance}")
        else:
            print("Сумма должна быть положительной")

    def withdraw(self, amount):
        if amount > self.balance:
            print("Недостаточно средств")
        else:
            self.balance -= amount
            print(f"Снято: {amount}. Баланс: {self.balance}")

class SavingsAccount(BankAccount):
    def __init__(self, owner, balance=0, interest_rate=0.05):
        super().__init__(owner, balance)
        self.interest_rate = interest_rate

    def add_interest(self):
        interest = self.balance * self.interest_rate
        self.balance += interest
        print(f"Проценты начислены: {interest:.2f}. Баланс: {self.balance:.2f}")

account = SavingsAccount("Пётр", 10000, 0.07)
account.deposit(5000)
account.add_interest()
account.withdraw(12000)
print(account)
```
-->

**Задание 17.** Реализуйте класс `Student` с атрибутами имя, оценки (словарь предмет → список оценок), методами `add_grade`, `average()`, `subject_average`.

<!-- ANSWER
```python
class Student:
    def __init__(self, name, grades=None):
        self.name = name
        self.grades = grades if grades is not None else {}

    def add_grade(self, subject, grade):
        if 1 <= grade <= 5:
            if subject not in self.grades:
                self.grades[subject] = []
            self.grades[subject].append(grade)
            print(f"{self.name}, {subject}: добавлена {grade}")
        else:
            print("Оценка должна быть от 1 до 5")

    def average(self):
        all_grades = [g for grades in self.grades.values() for g in grades]
        if not all_grades:
            return 0
        return sum(all_grades) / len(all_grades)

    def subject_average(self, subject):
        grades = self.grades.get(subject, [])
        return sum(grades) / len(grades) if grades else 0

    def __str__(self):
        avg = self.average()
        subjects = ', '.join(self.grades.keys())
        return f"{self.name} (средний балл: {avg:.2f}, предметы: {subjects})"

anna = Student("Анна")
anna.add_grade("математика", 5)
anna.add_grade("математика", 4)
anna.add_grade("физика", 5)
print(anna)
print(f"Средний балл по физике: {anna.subject_average('физика'):.2f}")
print(f"Средний балл выше 4.5: {anna.average() > 4.5}")
```
-->

**Задание 18.** Создайте класс `StudentRecord` с атрибутами имя, словарь предметов с оценками, методами `add_score`, `average_score`, `top_subject`.

<!-- ANSWER
```python
class StudentRecord:
    def __init__(self, name):
        self.name = name
        self.subjects = {}

    def add_score(self, subject, score):
        if 0 <= score <= 100:
            if subject not in self.subjects:
                self.subjects[subject] = []
            self.subjects[subject].append(score)
        else:
            print("Ошибка: оценка должна быть от 0 до 100")

    def average_score(self):
        all_scores = [s for scores in self.subjects.values() for s in scores]
        if not all_scores:
            return 0
        return sum(all_scores) / len(all_scores)

    def top_subject(self):
        if not self.subjects:
            return None
        return max(
            self.subjects.items(),
            key=lambda kv: sum(kv[1]) / len(kv[1]),
        )[0]

    def __str__(self):
        avg = self.average_score()
        top = self.top_subject()
        return f"Студент: {self.name}, средний балл: {avg:.1f}, лучший предмет: {top}"

record = StudentRecord("Иван Петров")
record.add_score("математика", 85)
record.add_score("математика", 92)
record.add_score("физика", 78)
record.add_score("химия", 95)
print(record)
```
-->

**Задание 19.** Реализуйте класс `ContactBook` с методами `add_contact`, `remove_contact`, `find_by_phone`, `__len__`, `__contains__`, `__str__`.

<!-- ANSWER
```python
class ContactBook:
    def __init__(self):
        self.contacts = {}

    def add_contact(self, name, phone, email=None):
        self.contacts[name] = {"phone": phone, "email": email}
        print(f"Контакт {name} добавлен")

    def remove_contact(self, name):
        if name in self.contacts:
            del self.contacts[name]
            print(f"Контакт {name} удалён")
        else:
            print("Контакт не найден")

    def find_by_phone(self, phone):
        results = [
            name for name, data in self.contacts.items()
            if data["phone"] == phone
        ]
        return results

    def __len__(self):
        return len(self.contacts)

    def __contains__(self, name):
        return name in self.contacts

    def __str__(self):
        lines = [f'{name}: {data["phone"]}' for name, data in self.contacts.items()]
        return "Контакты:\n" + "\n".join(lines) if lines else "Контактов нет"

book = ContactBook()
book.add_contact("Анна", "+7-999-123-45-67", "anna@example.com")
book.add_contact("Пётр", "+7-888-765-43-21")
book.add_contact("Мария", "+7-777-111-22-33")

print(f'Всего контактов: {len(book)}')
print(f'Анна есть в книге: {"Анна" in book}')
print(f'Поиск +7-888-765-43-21: {book.find_by_phone("+7-888-765-43-21")}')
book.remove_contact("Мария")
print(book)
```
-->

**Задание 20.** Реализуйте функцию `find_anagrams(words)`, которая находит группы анаграмм в списке слов.

Исходный список слов
```python
words = ["listen", "silent", "hello", "enlist", "world", "dlrow"]
```

<!-- ANSWER
```python
def find_anagrams(words):
    groups = {}
    for word in words:
        key = ''.join(sorted(word.lower()))
        groups.setdefault(key, []).append(word)
    return [group for group in groups.values() if len(group) > 1]

for group in find_anagrams(words):
    print(group)
```
-->

---

## 📌 Отчёт о выполненной работе

1. Добавьте в конец Jupyter Notebook `Pr_3_report.ipynb` Markdown-ячейку с ответами на контрольные вопросы из раздела [«Контрольные вопросы»](Pr_3.md#контрольные-вопросы)
   - Тип ячейки выбирается в верхней части окна Jupyter Notebook'а из выпадающего списка, где по умолчанию стоит значение `Code`
2. Сохраните Jupyter Notebook
3. Загрузите файл в свой репозиторий в GitLab:
   - В левом окне Jupyter Lab (файловом менеджере) перейдите в каталог `project` (поднимитесь на два уровня вверх: из `Pr_3` в `reports` -> `project`)
   - Создайте новую вкладку типа `Terminal` (File -> New -> Terminal)
   - Введите

```bash
git add .
git commit -m "Pr_3 notebook report"
git push
```

> ⏳ Оценка запустится автоматически в GitLab CI. Результат появится в разделе **CI/CD → Pipelines**.

---

## Контрольные вопросы

1. Чем `def`-функция отличается от `lambda` и где уместно использовать замыкание?
2. Как используются `*args`, `**kwargs` и значения параметров по умолчанию?
3. Что такое `self`, инициализация `__init__` и магические методы класса?
4. Как устроены наследование, MRO и переопределение методов в Python?
5. Как инкапсуляция и свойства (`@property`) защищают состояние объекта?
