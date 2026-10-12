--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Задание 1: список из 10 случайных чисел от 1 до 100, максимум/минимум с индексами
import random

numbers = [random.randint(1, 100) for _ in range(10)]
print(f"Список: {numbers}")

print(f"Максимум: {max(numbers)} (индекс {numbers.index(max(numbers))})")
print(f"Минимум: {min(numbers)} (индекс {numbers.index(min(numbers))})")
[вывод] Список: [42, 7, 88, 3, 56, 19, 74, 25, 91, 12]
Максимум: 91 (индекс 8)
Минимум: 3 (индекс 3)

--- Ячейка кода 3 ---
# Задание 2: слова длиной больше 4 символов, отсортированные по алфавиту
words = ["банан", "яблоко", "вишня", "груша", "слива", "абрикос", "персик"]

long_words = sorted([w for w in words if len(w) > 4])
print(long_words)
[вывод] ['абрикос', 'банан', 'вишня', 'персик', 'яблоко']

--- Ячейка кода 4 ---
# Задание 3: город с максимальной средней температурой
temperatures = {
    "Москва": [22, 24, 21, 23, 25],
    "Санкт-Петербург": [18, 19, 17, 20, 18],
    "Казань": [25, 27, 26, 24, 28],
}

best_city = None
best_avg = -1
for city, temps in temperatures.items():
    avg = sum(temps) / len(temps)
    if best_city is None or avg > best_avg:
        best_city = city
        best_avg = avg

print(f"Самый тёплый город: {best_city} (средняя {best_avg:.1f}°C)")
[вывод] Самый тёплый город: Казань (средняя 26.0°C)

--- Ячейка кода 5 ---
# Задание 4: средний балл каждого студента, рейтинг по убыванию
grades = {
    "Анна": [5, 4, 5, 5, 4],
    "Пётр": [4, 4, 3, 4, 4],
    "Мария": [5, 5, 5, 5, 5],
    "Иван": [3, 4, 3, 4, 3],
}

averages = [(name, sum(student_grades) / len(student_grades)) for name, student_grades in grades.items()]
averages.sort(key=lambda item: item[1], reverse=True)
for name, avg in averages:
    print(f"{name}: {avg:.2f}")
[вывод] Мария: 5.00
Анна: 4.60
Пётр: 3.80
Иван: 3.40

--- Ячейка кода 6 ---
# Задание 5: словарь «длина слова -> список слов такой длины», по возрастанию длины
words = ["hi", "hello", "world", "python", "a", "code", "programming", "go"]

groups = {}
for word in words:
    length = len(word)
    if length not in groups:
        groups[length] = []
    groups[length].append(word)

result = {length: groups[length] for length in sorted(groups)}
for length, word_list in result.items():
    print(f"{length}: {word_list}")
[вывод] 1: ['a']
2: ['hi', 'go']
4: ['code']
5: ['hello', 'world']
6: ['python']
11: ['programming']

--- Ячейка кода 7 ---
# Задание 6: статистика по тексту — слова, уникальные, средняя длина, частое слово
text = "python is great python is fun python is powerful and python is easy"

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
[вывод] total_words: 14
unique_words: 8
avg_length: 4.79
most_common: python
most_common_count: 4

--- Ячейка кода 8 ---
# Задание 7: сортировка кортежей (имя, возраст, курс) по возрасту, затем по имени
students = [("Мария", 20, 2), ("Анна", 19, 1), ("Пётр", 21, 3), ("Иван", 19, 2)]

sorted_students = sorted(students, key=lambda s: (s[1], s[0]))
for name, age, course in sorted_students:
    print(f"{name}, {age} лет, курс {course}")
[вывод] Анна, 19 лет, курс 1
Иван, 19 лет, курс 2
Мария, 20 лет, курс 2
Пётр, 21 лет, курс 3

--- Ячейка кода 9 ---
# Задание 8: общие и уникальные элементы двух множеств слов
text1 = "python is great and python is fun".split()
text2 = "python is powerful and easy to learn".split()

set1 = set(text1)
set2 = set(text2)

print(f"Уникальные для текста 1: {set1 - set2}")
print(f"Уникальные для текста 2: {set2 - set1}")
print(f"Общие слова: {set1 & set2}")
print(f"Все слова: {set1 | set2}")
[вывод] Уникальные для текста 1: {'great', 'fun'}
Уникальные для текста 2: {'to', 'learn', 'powerful', 'easy'}
Общие слова: {'python', 'is', 'and'}
Все слова: {'python', 'is', 'and', 'great', 'fun', 'powerful', 'easy', 'to', 'learn'}

--- Ячейка кода 10 ---
# Задание 9: таблица умножения 10x10 вложенными циклами for
for i in range(1, 11):
    row = [f"{i*j:3d}" for j in range(1, 11)]
    print(" | ".join(row))
[вывод]   1 |   2 |   3 |   4 |   5 |   6 |   7 |   8 |   9 |  10
  2 |   4 |   6 |   8 |  10 |  12 |  14 |  16 |  18 |  20
  3 |   6 |   9 |  12 |  15 |  18 |  21 |  24 |  27 |  30
  4 |   8 |  12 |  16 |  20 |  24 |  28 |  32 |  36 |  40
  5 |  10 |  15 |  20 |  25 |  30 |  35 |  40 |  45 |  50
  6 |  12 |  18 |  24 |  30 |  36 |  42 |  48 |  54 |  60
  7 |  14 |  21 |  28 |  35 |  42 |  49 |  56 |  63 |  70
  8 |  16 |  24 |  32 |  40 |  48 |  56 |  64 |  72 |  80
  9 |  18 |  27 |  36 |  45 |  54 |  63 |  72 |  81 |  90
 10 |  20 |  30 |  40 |  50 |  60 |  70 |  80 |  90 | 100

--- Ячейка кода 11 ---
# Задание 10: средний балл по каждому предмету
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
[вывод] математика: 4.00
физика: 4.33
информатика: 4.67

--- Ячейка кода 12 ---
# Задание 11: калькулятор, читает выражения до ввода exit
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
[вывод] Введите выражение (или 'exit'): 2 + 3
Результат: 5.0
Введите выражение (или 'exit'): 10 / 4
Результат: 2.5
Введите выражение (или 'exit'): exit
Завершение работы.

--- Ячейка Markdown 1 ---
## Ответы на контрольные вопросы

1. Список (list) — изменяемая коллекция, допускает повторяющиеся элементы; кортеж (tuple) — неизменяемый (после создания его нельзя изменить), тоже допускает повторения; множество (set) — изменяемое, но хранит только уникальные элементы, дубликаты не сохраняются.
2. Индексация даёт доступ к элементу по его номеру (отрицательные индексы считаются с конца); срезы [start:stop:step] извлекают фрагмент списка, включая реверс [::-1]; методы append, insert, pop, remove, sort и reverse изменяют список на месте.
3. Словарь хранит пары «ключ — значение» и позволяет быстро получить значение по уникальному ключу (ключи должны быть хешируемыми). Безопасно значение получают через .get(key, default): если ключа нет, вернётся None или значение по умолчанию, а не исключение KeyError, которое даёт прямой доступ d[key].
4. for + range применяют, когда нужно повторить действие фиксированное количество раз или получить последовательность чисел; enumerate — когда при обходе коллекции нужны сразу и индекс, и значение элемента; zip — для параллельной итерации по нескольким коллекциям с сопоставлением элементов по позициям.
5. break досрочно прерывает цикл (выход из него); continue пропускает текущую итерацию и переходит к следующей; блок else выполняется, если цикл завершился без break, то есть когда условие цикла стало ложным.
