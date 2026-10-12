--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Задание 1: первые n чисел Фибоначчи
def fibonacci(n):
    a, b = 0, 1
    result = []
    for _ in range(n):
        result.append(a)
        a, b = b, a + b
    return result

print(fibonacci(10))
[вывод] [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]

--- Ячейка кода 3 ---
# Задание 2: распрямление вложенного списка любой глубины
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
[вывод] [1, 2, 3, 4, 5, 6, 7]

--- Ячейка кода 4 ---
# Задание 3: словарь частот слов (без учёта регистра)
def word_freq(text):
    words = text.lower().split()
    freq = {}
    for word in words:
        freq[word] = freq.get(word, 0) + 1
    return freq

text = "Python is great and Python is fun"
for word, count in word_freq(text).items():
    print(f"{word}: {count}")
[вывод] python: 2
is: 1
great: 1
and: 1
fun: 1

--- Ячейка кода 5 ---
# Задание 4: map(), filter(), reduce()
from functools import reduce

numbers = list(range(1, 11))
squares = list(map(lambda x: x ** 2, numbers))
evens = list(filter(lambda x: x % 2 == 0, numbers))
total = reduce(lambda a, b: a + b, numbers)

print(f"Квадраты: {squares}")
print(f"Чётные: {evens}")
print(f"Сумма: {total}")
[вывод] Квадраты: [1, 4, 9, 16, 25, 36, 49, 64, 81, 100]
Чётные: [2, 4, 6, 8, 10]
Сумма: 55

--- Ячейка кода 6 ---
# Задание 5: транспонирование матрицы
matrix = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

def matrix_transpose(matrix_):
    if not matrix_:
        return []
    rows = len(matrix_)
    cols = len(matrix_[0])
    return [[matrix_[r][c] for r in range(rows)] for c in range(cols)]

for row in matrix_transpose(matrix):
    print(row)
[вывод] [1, 4, 7]
[2, 5, 8]
[3, 6, 9]

--- Ячейка кода 7 ---
# Задание 6: уникальные элементы с сохранением порядка
data = [1, 2, 2, 3, 4, 3, 5, 1]

def unique_elements(lst):
    return list(dict.fromkeys(lst))

print(unique_elements(data))
print(dict.fromkeys(data))
[вывод] [1, 2, 3, 4, 5]
{1: None, 2: None, 3: None, 4: None, 5: None}

--- Ячейка кода 8 ---
# Задание 7: обмен значениями двух переменных
def swap(a, b):
    a, b = b, a
    return a, b

x, y = 10, 20
x, y = swap(x, y)
print(x, y)
[вывод] 20 10

--- Ячейка кода 9 ---
# Задание 8: разворот числа (обработка отрицательных)
def reverse_number(n):
    if n >= 0:
        return int(str(n)[::-1])
    return -int(str(-n)[::-1])

print(reverse_number(12300))
print(reverse_number(-456))
[вывод] 321
-654

--- Ячейка кода 10 ---
# Задание 9: алгоритм Евклида для НОД
def gcd(a, b):
    while b:
        a, b = b, a % b
    return abs(a)

print(gcd(48, 18))
[вывод] 6

--- Ячейка кода 11 ---
# Задание 10: гипотеза Коллатца — шаги до единицы
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
[вывод] 111

--- Ячейка кода 12 ---
# Задание 11: все дубликаты в списке
data = [1, 2, 3, 2, 4, 5, 3, 6]

def find_duplicates(lst):
    seen = set()
    duplicates = set()
    for item in lst:
        if item in seen:
            duplicates.add(item)
        seen.add(item)
    return list(duplicates)

print(find_duplicates(data))
[вывод] [2, 3]

--- Ячейка кода 13 ---
# Задание 12: инверсия словаря (значение -> список ключей)
d = {"a": 1, "b": 1, "c": 2, "d": 2, "e": 3}

def invert_dict(d):
    inverted = {}
    for key, value in d.items():
        inverted.setdefault(value, []).append(key)
    return inverted

for value, keys in invert_dict(d).items():
    print(f"{value}: {keys}")
[вывод] 1: ['a', 'b']
2: ['c', 'd']
3: ['e']

--- Ячейка кода 14 ---
# Задание 13: объединение словарей с суммированием значений
d1 = {"a": 1, "b": 2, "c": 3}
d2 = {"b": 5, "c": 7, "d": 4}

def merge_dicts(*dicts):
    result = {}
    for d in dicts:
        for key, value in d.items():
            result[key] = result.get(key, 0) + value
    return result

print(merge_dicts(d1, d2))
[вывод] {'a': 1, 'b': 7, 'c': 10, 'd': 4}

--- Ячейка кода 15 ---
# Задание 14: инвертированный индекс word -> позиции
text = "to be or not to be thats the question to be"

def word_index(text):
    words = text.lower().split()
    index = {}
    for i, word in enumerate(words):
        index.setdefault(word, []).append(i)
    return index

for word, positions in sorted(word_index(text).items()):
    print(f"{word}: {positions}")
[вывод] be: [5, 10]
not: [6]
or: [4]
question: [9]
thats: [7]
the: [8]
to: [0, 3, 8]

--- Ячейка кода 16 ---
# Задание 15: класс BankAccount с проверками
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
[вывод] Внесено: 500. Баланс: 1500
Снято: 200. Баланс: 1300
Недостаточно средств
Анна: 1300 руб.

--- Ячейка кода 17 ---
# Задание 16: наследование — SavingsAccount с процентами
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
[вывод] Внесено: 5000. Баланс: 15000
Проценты начислены: 1050.00. Баланс: 16050.00
Снято: 12000. Баланс: 4050.00
Пётр: 4050.0 руб.

--- Ячейка кода 18 ---
# Задание 17: класс Student — оценки по предметам
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
[вывод] Анна, математика: добавлена 5
Анна, математика: добавлена 4
Анна, физика: добавлена 5
Анна (средний балл: 4.67, предметы: математика, физика)
Средний балл по физике: 5.00
Средний балл выше 4.5: True

--- Ячейка кода 19 ---
# Задание 18: класс StudentRecord — оценки 0-100
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
[вывод] Студент: Иван Петров, средний балл: 87.5, лучший предмет: химия

--- Ячейка кода 20 ---
# Задание 19: класс ContactBook — телефонная книга
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
[вывод] Контакт Анна добавлен
Контакт Пётр добавлен
Контакт Мария добавлен
Всего контактов: 3
Анна есть в книге: True
Поиск +7-888-765-43-21: ['Пётр']
Контакт Мария удалён
Контакты:
Анна: +7-999-123-45-67
Пётр: +7-888-765-43-21

--- Ячейка кода 21 ---
# Задание 20: группы анаграмм
words = ["listen", "silent", "hello", "enlist", "world", "dlrow"]

def find_anagrams(words):
    groups = {}
    for word in words:
        key = ''.join(sorted(word.lower()))
        groups.setdefault(key, []).append(word)
    return [group for group in groups.values() if len(group) > 1]

for group in find_anagrams(words):
    print(group)
[вывод] ['listen', 'silent', 'enlist']
['hello', 'dlrow']

--- Ячейка Markdown 1 ---
## Ответы на контрольные вопросы

1. def-функция — именованная, может содержать несколько операторов и документацию; lambda — анонимная функция из одного выражения. Замыкание уместно, когда нужно запоминать переменные внешней области видимости даже после её завершения (например, параметризированные обработчики).
2. *args собирает произвольное число позиционных аргументов в кортеж, **kwargs — именованные аргументы в словарь; значения параметров по умолчанию подставляются, когда аргумент не передан при вызове.
3. self — это ссылка на экземпляр (объект) внутри методов класса; __init__ инициализирует атрибуты объекта при его создании; магические методы (__str__, __len__ и др.) переопределяют операторы и специальное поведение класса.
4. Дочерний класс наследует атрибуты и методы родительского класса; MRO — порядок, в котором Python ищет методы по цепочке наследования (C3-линейизация); super() вызывает метод родителя; переопределение — повторное определение метода в дочернем классе.
5. Инкапсуляция скрывает внутренние атрибуты объекта (приватные с префиксом _); декоратор @property даёт доступ через геттер и сеттер с проверкой, защищая состояние от некорректных изменений.
