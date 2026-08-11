# Директория методических указаний

## Справочные материалы

- [Синтаксис Markdown](./MD_Instructions.md) — полный справочник по разметке MD-файлов

## Ключевые практические работы

1. [Предварительная настройка учебного комплекса](./Pr_0.md)
2. [Основы Git и GitLab](./Pr_1.md)
3. [Основы контейнеризации и чат-боты для мессенджера MAX](./Pr_2.md)
4. [Знакомство с Python. Функции и ООП](./Pr_3.md)
5. [Основы контейнеризации и чат-боты для мессенджера MAX](./Pr_4.md)
6. [Визуализация данных средствами MatplotLib. Основы](./Pr_5.md)
7. [Визуализация данных средствами MatplotLib. Диаграммы](./Pr_6.md)
8. [Работа с облачными системами хранения и визуализации данных](./Pr_7.md)
9. [Машинное обучение. K-Means Clustering](./Pr_8.md)
10. [Машинное обучение. K-Nearest Neighbors](./Pr_9.md)
11. [Машинное обучение. Density-Based Clustering](./Pr_10.md)
12. [Машинное обучение. Hierarchical Clustering](./Pr_11.md)
13. [Машинное обучение. Decision Trees](./Pr_12.md)
14. [Машинное обучение. SVM (Support Vector Machines)](./Pr_13.md)
15. [Машинное обучение. Logistic Regression with Python](./Pr_14.md)
16. [Машинное обучение. Collaborative filtering](./Pr_15.md)
17. [Машинное обучение. Content-based filtering](./Pr_16.md)
18. [Машинное обучение. Simple Linear Regression](./Pr_17.md)
19. [Машинное обучение. Multiple Linear Regression](./Pr_18.md)
20. [Машинное обучение. Non Linear Regression Analysis](./Pr_19.md)
21. [Машинное обучение. Классификаторы изображений](./Pr_20.md)
22. [Машинное обучение. Суммаризация и классификация текстов](./Pr_21.md)

## Доступ к сервисам

| Сервис | URL | Описание |
|--------|-----|----------|
| **GitLab** | `http://<server-ip>:80` | Исходный код, репозиторий методичек |
| **JupyterHub** | `http://<server-ip>:8000` | JupyterLab, терминал, Python-среда |
| **Dashboard** | `http://<server-ip>:9000` | Панель преподавателя |
| **Docker Registry** | `http://<server-ip>:5050` | Хранение Docker-образов (standalone) |

## Типы работ

### Terminal-based (Pr_0, Pr_1)
Работы выполняются в терминале JupyterLab. Отчёт — файл `.md` в формате Markdown.

### Notebook-based (Pr_2 — Pr_21)
Работы выполняются в JupyterLab. Доступен ИИ-ментор (`%%ask_mentor`). Отчёт — `.ipynb` с LLM-проверкой.

## Формат отчётов

Все отчёты сохраняются в формате **Markdown** (`.md`):
- Создавайте файлы `.md` в JupyterLab
- Используйте [справочник по Markdown](./MD_Instructions.md) для форматирования
- Загружайте `.md` файлы в ваш репозиторий `reports_<группа>_<номер>` в GitLab
