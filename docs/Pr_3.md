# Практическая работа №3
# Практическая работа №3: Знакомство с Python. Функции и объектно-ориентированное программирование

---

## 🎯 Цель работы

Приобрести практические навыки работы с функциями и основами объектно-ориентированного программирования на Python.

---

## ⚠️ Важно

Это работа в формате **Notebook-based**. Вам будет доступен **ИИ-ментор** (`%%ask_mentor`). Все запросы логируются.

---

## 📚 Основные идеи и теоретические основы.

### Функции

Функция — именованный блок кода, который можно вызывать многократно. Функции повышают читаемость и переиспользуемость кода.

```python
# Базовое определение функции
def greet(name):
    return f"Привет, {name}!"

print(greet("Анна"))  # Привет, Анна!

# Параметры по умолчанию
def power(base, exp=2):
    return base ** exp

print(power(3))     # 9
print(power(3, 3))  # 27

# *args — неограниченное количество позиционных аргументов
def total(*args):
    return sum(args)

print(total(1, 2, 3, 4))  # 10

# **kwargs — неограниченное количество именованных аргументов
def build_profile(**kwargs):
    for key, value in kwargs.items():
        print(f"{key}: {value}")

build_profile(name="Иван", age=25, city="Москва")

# lambda — анонимные функции
square = lambda x: x ** 2
print(square(5))  # 25

# map() — применение функции к каждому элементу
numbers = [1, 2, 3, 4, 5]
squared = list(map(square, numbers))
# [1, 4, 9, 16, 25]

# filter() — фильтрация по условию
evens = list(filter(lambda x: x % 2 == 0, numbers))
# [2, 4]

# reduce() — накопление результата (в Python 3 — в functools)
from functools import reduce
product = reduce(lambda a, b: a * b, numbers)
# 120 (1*2*3*4*5)
```

### Область видимости

```python
# global — переменная доступна во всей программе
counter = 0

def increment():
    global counter
    counter += 1

increment()
print(counter)  # 1

# nonlocal — доступ к переменной внешней функции
def outer():
    x = "внешняя"
    def inner():
        nonlocal x
        x = "изменённая"
        print(x)
    inner()
    print(x)  # изменённая

outer()
```

### Классы и объекты

Класс — шаблон для создания объектов. Объект — экземпляр класса.

```python
# Определение класса
class Animal:
    # Конструктор (инициализация)
    def __init__(self, name, age):
        self.name = name
        self.age = age
        self._legs = 4  # protected
    
    # Метод экземпляра
    def speak(self):
        return f"{self.name} издаёт звук"
    
    # Строковое представление
    def __str__(self):
        return f"Animal({self.name}, {self.age} лет)"

# Создание объекта
dog = Animal("Рекс", 3)
print(dog.name)    # Рекс
print(dog.speak()) # Рекс издаёт звук
print(dog)         # Animal(Рекс, 3 лет)
```

### Наследование

Наследование позволяет создавать новые классы на основе существующих.

```python
class Dog(Animal):
    def __init__(self, name, age, breed):
        super().__init__(name, age)
        self.breed = breed
    
    def speak(self):
        return f"{self.name}: гав!"
    
    def fetch(self, item):
        return f"{self.name} принёс {item}"

my_dog = Dog("Бобик", 5, "лабрадор")
print(my_dog.speak())   # Бобик: гав!
print(my_dog.fetch("мяч"))  # Бобик принёс мяч
```

### Магические методы

```python
class Vector:
    def __init__(self, x, y):
        self.x = x
        self.y = y
    
    def __add__(self, other):
        return Vector(self.x + other.x, self.y + other.y)
    
    def __mul__(self, scalar):
        return Vector(self.x * scalar, self.y * scalar)
    
    def __len__(self):
        return int((self.x ** 2 + self.y ** 2) ** 0.5)
    
    def __str__(self):
        return f"({self.x}, {self.y})"
    
    def __eq__(self, other):
        return self.x == other.x and self.y == other.y

v1 = Vector(1, 2)
v2 = Vector(3, 4)
v3 = v1 + v2
print(v3)       # (4, 6)
print(v1 * 3)   # (3, 6)
print(len(v1))  # 2
```

### Декораторы

Декоратор — функция, которая изменяет поведение другой функции.

```python
import time

def timer(func):
    def wrapper(*args, **kwargs):
        start = time.time()
        result = func(*args, **kwargs)
        end = time.time()
        print(f"{func.__name__} занял {end - start:.4f} сек")
        return result
    return wrapper

@timer
def slow_function():
    total = 0
    for i in range(1000000):
        total += i
    return total

slow_function()
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

### 📌 Практика 1: Функции и их параметры

**Задание 1.** Напишите функцию `fibonacci(n)`, возвращающую n-е число Фибоначчи.

```python
def fibonacci(n):
    if n <= 0:
        return 0
    if n == 1:
        return 1
    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b

print([fibonacci(i) for i in range(10)])
# [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
```

**Задание 2.** Напишите функцию `flatten_list(lst)`, которая «сплющивает» вложенный список в одномерный.

```python
def flatten_list(lst):
    result = []
    for item in lst:
        if isinstance(item, list):
            result.extend(flatten_list(item))
        else:
            result.append(item)
    return result

nested = [1, [2, 3], [4, [5, 6]], 7]
print(flatten_list(nested))  # [1, 2, 3, 4, 5, 6, 7]
```

**Задание 3.** Напишите функцию `word_freq(text)`, которая возвращает словарь частотности слов в тексте.

```python
def word_freq(text):
    words = text.lower().split()
    freq = {}
    for word in words:
        freq[word] = freq.get(word, 0) + 1
    return freq

text = "python is great and python is fun and python is powerful"
print(word_freq(text))
# {'python': 3, 'is': 3, 'great': 1, 'and': 2, 'fun': 1, 'powerful': 1}
```

**Задание 4.** Используйте `map()`, `filter()` и `reduce()` для обработки списка:
- возведите каждое число в квадрат
- отфильтруйте чётные квадраты
- найдите сумму

```python
from functools import reduce
numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

squared = list(map(lambda x: x ** 2, numbers))
evens = list(filter(lambda x: x % 2 == 0, squared))
total = reduce(lambda a, b: a + b, evens)

print(f"Квадраты: {squared}")
print(f"Чётные: {evens}")
print(f"Сумма чётных квадратов: {total}")
```

---

### 📌 Практика 2: Классы и наследование

**Задание 5.** Создайте класс `BankAccount` с методами `deposit()`, `withdraw()`, `get_balance()`.

```python
class BankAccount:
    def __init__(self, owner, balance=0):
        self.owner = owner
        self._balance = balance
    
    def deposit(self, amount):
        self._balance += amount
        return f"Внесено: {amount}. Баланс: {self._balance}"
    
    def withdraw(self, amount):
        if amount > self._balance:
            return "Недостаточно средств"
        self._balance -= amount
        return f"Снято: {amount}. Баланс: {self._balance}"
    
    def get_balance(self):
        return self._balance

account = BankAccount("Анна", 1000)
print(account.deposit(500))    # Внесено: 500. Баланс: 1500
print(account.withdraw(300))   # Снято: 300. Баланс: 1200
print(account.get_balance())   # 1200
```

**Задание 6.** Создайте подкласс `SavingsAccount` с методом начисления процентов.

```python
class SavingsAccount(BankAccount):
    def __init__(self, owner, balance=0, interest_rate=0.05):
        super().__init__(owner, balance)
        self.interest_rate = interest_rate
    
    def add_interest(self):
        interest = self._balance * self.interest_rate
        self._balance += interest
        return f"Начислено процентов: {interest:.2f}"

savings = SavingsAccount("Пётр", 10000, 0.05)
print(savings.add_interest())  # Начислено процентов: 500.00
print(savings.get_balance())   # 10500
```

**Задание 7.** Создайте класс `Student` с `__str__`, `__eq__` и методом расчёта среднего балла.

```python
class Student:
    def __init__(self, name, grades):
        self.name = name
        self.grades = grades
    
    def average(self):
        return sum(self.grades) / len(self.grades)
    
    def __str__(self):
        return f"Student({self.name}, avg={self.average():.2f})"
    
    def __eq__(self, other):
        return self.name == other.name and self.average() == other.average()

anna = Student("Анна", [5, 4, 5, 5])
petr = Student("Пётр", [4, 4, 4, 4])
print(anna)          # Student(Анна, avg=4.75)
print(anna > petr)   # True (по среднему баллу)
```

---

### 📌 Практика 3: Декораторы и lambda

**Задание 8.** Напишите декоратор `retry(func, max_retries=3)`, который повторяет вызов функции при ошибке.

```python
import random

def retry(func, max_retries=3):
    def wrapper(*args, **kwargs):
        for attempt in range(max_retries):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                if attempt == max_retries - 1:
                    raise
                print(f"Попытка {attempt + 1} провалилась: {e}")
    return wrapper

@retry
def unstable_function():
    value = random.random()
    if value < 0.5:
        raise ValueError(f"Случайное значение {value:.2f} слишком мало")
    return f"Успех: {value:.2f}"

print(unstable_function())
```

**Задание 9.** Напишите декоратор `log_calls(func)`, который логирует вызовы функций.

```python
import time

def log_calls(func):
    def wrapper(*args, **kwargs):
        args_str = ', '.join(repr(a) for a in args)
        kwargs_str = ', '.join(f"{k}={repr(v)}" for k, v in kwargs.items())
        print(f"Вызов: {func.__name__}({args_str}, {kwargs_str})")
        start = time.time()
        result = func(*args, **kwargs)
        elapsed = time.time() - start
        print(f"  Результат: {result}, время: {elapsed:.4f} сек")
        return result
    return wrapper

@log_calls
def multiply(a, b):
    return a * b

multiply(6, 7)
```

---

### 📌 Практика 4: Комбинированные задачи

**Задание 10.** Реализуйте класс `LinkedList` с методами `append()`, `remove()`, `length()`, `__str__()`.

```python
class Node:
    def __init__(self, data):
        self.data = data
        self.next = None

class LinkedList:
    def __init__(self):
        self.head = None
    
    def append(self, data):
        new_node = Node(data)
        if not self.head:
            self.head = new_node
            return
        current = self.head
        while current.next:
            current = current.next
        current.next = new_node
    
    def remove(self, data):
        if not self.head:
            return
        if self.head.data == data:
            self.head = self.head.next
            return
        current = self.head
        while current.next:
            if current.next.data == data:
                current.next = current.next.next
                return
            current = current.next
    
    def length(self):
        count = 0
        current = self.head
        while current:
            count += 1
            current = current.next
        return count
    
    def __str__(self):
        elements = []
        current = self.head
        while current:
            elements.append(str(current.data))
            current = current.next
        return ' -> '.join(elements)

ll = LinkedList()
ll.append(1)
ll.append(2)
ll.append(3)
print(ll)        # 1 -> 2 -> 3
print(ll.length())  # 3
ll.remove(2)
print(ll)        # 1 -> 3
```

**Задание 11.** Решите задачу: создайте функцию `find_anagrams(words)`, которая группирует слова-анаграммы.

```python
from collections import defaultdict

def find_anagrams(words):
    groups = defaultdict(list)
    for word in words:
        key = ''.join(sorted(word.lower()))
        groups[key].append(word)
    return {k: v for k, v in groups.items() if len(v) > 1}

words = ['listen', 'silent', 'hello', 'world', 'enlist', 'inlets', 'python']
anagrams = find_anagrams(words)
for key, group in anagrams.items():
    print(f"{key}: {group}")
# 'eilnst': ['listen', 'silent', 'enlist', 'inlets']
```

**Задание 12.** Создайте класс `Matrix` с поддержкой сложения, умножения на скаляр и вывода.

```python
class Matrix:
    def __init__(self, data):
        self.data = data
        self.rows = len(data)
        self.cols = len(data[0])
    
    def __add__(self, other):
        result = [
            [self.data[i][j] + other.data[i][j] for j in range(self.cols)]
            for i in range(self.rows)
        ]
        return Matrix(result)
    
    def __mul__(self, scalar):
        result = [
            [self.data[i][j] * scalar for j in range(self.cols)]
            for i in range(self.rows)
        ]
        return Matrix(result)
    
    def __str__(self):
        return '\n'.join([' | '.join(f"{x:6d}" for x in row) for row in self.data])

m1 = Matrix([[1, 2], [3, 4]])
m2 = Matrix([[5, 6], [7, 8]])
print(m1 + m2)
print(m1 * 3)
```

---

## 📌 Отчёт о выполненной работе

1. Сохраните все ячейки с выполненными заданиями в Jupyter Notebook
2. Добавьте краткие комментарии к каждому заданию
3. Добавьте Markdown-ячейку с ответами на контрольные вопросы из раздела «Контрольные вопросы»
4. Сохраните ноутбук как `Pr_3_<группа>_<номер>.ipynb`
5. Загрузите файл в репозиторий `reports_<группа>_<номер>` в GitLab:

```bash
git add Pr_3_<группа>_<номер>.ipynb
git commit -m "Pr_3 notebook"
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

## Контрольные вопросы

1. Зачем нужны параметры функции со значением по умолчанию, `*args` и `**kwargs`?
2. Чем локальная и глобальная области видимости отличаются и для чего нужны `global`/`nonlocal`?
3. Какие задачи решают `lambda`, `map`, `filter` и `reduce`?
4. Из чего состоит класс в Python: `__init__`, `self`, атрибуты и методы?
5. Как наследование и `super()` позволяют переиспользовать и расширять код?
