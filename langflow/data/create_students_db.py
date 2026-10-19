"""
Скрипт для автоматической генерации файла БД SQLite students.db
Запуск: python3 create_students_db.py
"""
import sqlite3
import os

db_filename = "students.db"

sql_script = """
DROP TABLE IF EXISTS grades;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;

CREATE TABLE students (
    student_id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name TEXT NOT NULL,
    group_num TEXT NOT NULL
);

CREATE TABLE courses (
    course_id INTEGER PRIMARY KEY,
    course_name TEXT NOT NULL
);

CREATE TABLE grades (
    student_id INTEGER,
    course_id INTEGER,
    grade INTEGER CHECK (grade BETWEEN 2 AND 5),
    PRIMARY KEY (student_id, course_id),
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (course_id) REFERENCES courses(course_id)
);

INSERT INTO students (student_id, full_name, group_num) VALUES 
(1, 'Иванов Иван Иванович', 'ИВТ-401'),
(2, 'Петрова Анна Сергеевна', 'ИВТ-401'),
(3, 'Сидоров Алексей Владимирович', 'ИВТ-402'),
(4, 'Смирнова Елена Михайловна', 'ИВТ-402'),
(5, 'Кузнецов Дмитрий Игоревич', 'ИВТ-401');

INSERT INTO courses (course_id, course_name) VALUES 
(101, 'Интеллектуальные системы и технологии'),
(102, 'Базы данных'),
(103, 'Машинное обучение'),
(104, 'Нейронные сети');

INSERT INTO grades (student_id, course_id, grade) VALUES 
(1, 101, 5), (1, 102, 4), (1, 103, 5),
(2, 101, 5), (2, 102, 5), (2, 104, 4),
(3, 101, 3), (3, 102, 4), (3, 103, 3),
(4, 101, 5), (4, 104, 5),
(5, 102, 3), (5, 103, 4);
"""

if __name__ == "__main__":
    if os.path.exists(db_filename):
        os.remove(db_filename)
    conn = sqlite3.connect(db_filename)
    cursor = conn.cursor()
    cursor.executescript(sql_script)
    conn.commit()
    conn.close()
    print(f"База данных {db_filename} успешно создана и заполнена тестовыми данными.")
