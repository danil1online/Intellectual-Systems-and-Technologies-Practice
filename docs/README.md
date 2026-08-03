# Директория методических указаний

## Справочные материалы

- [Синтаксис Markdown](./MD_Instructions.md) — полный справочник по разметке MD-файлов

## Ключевые практические работы

1. [Предварительная настройка учебного комплекса](./Pr_0.md)
2. [Основы Git и GitLab](./Pr_1.md)
3. [Основы работы с технологиями контейнеризации и ботами Telegram](./Pr_2.md)
4. [Знакомство с Python](./Pr_3.md)
5. [Визуализация данных средствами MatplotLib. Основы](./Pr_4.md)
6. [Визуализация данных средствами MatplotLib. Диаграммы](./Pr_5.md)
7. [Работа с облачными системами хранения и визуализации данных](./Pr_6.md)
8. [Машинное обучение. K-Means Clustering](./Pr_7.md)
9. [Машинное обучение. K-Nearest Neighbors](./Pr_8.md)
10. [Машинное обучение. Density-Based Clustering](./Pr_9.md)
11. [Машинное обучение. Hierarchical Clustering](./Pr_10.md)
12. [Машинное обучение. Decision Trees](./Pr_11.md)
13. [Машинное обучение. SVM (Support Vector Machines)](./Pr_12.md)
14. [Машинное обучение. Logistic Regression with Python](./Pr_13.md)
15. [Машинное обучение. Collaborative filtering](./Pr_14.md)
16. [Машинное обучение. Content-based filtering](./Pr_15.md)
17. [Машинное обучение. Simple Linear Regression](./Pr_16.md)
18. [Машинное обучение. Multiple Linear Regression](./Pr_17.md)
19. [Машинное обучение. Non Linear Regression Analysis](./Pr_18.md)
20. [Машинное обучение. Классификаторы изображений](./Pr_19.md)
21. [Машинное обучение. Суммаризация и классификация текстов](./Pr_20.md)

## Доступ к сервисам

| Сервис | URL | Описание |
|--------|-----|----------|
| **GitLab** | `http://<server-ip>:80` | Исходный код, репозиторий методичек |
| **JupyterHub** | `http://<server-ip>:8000` | JupyterLab, терминал, Python-среда |
| **Nextcloud** | `http://<server-ip>:8080` | Облачное хранилище, файлы Markdown |
| **Dashboard** | `http://<server-ip>:9000` | Панель преподавателя |

## Типы работ

### Terminal-based (Pr_0, Pr_1, Pr_2)
Работы выполняются в терминале JupyterLab. Отчёт — файл `.md` в формате Markdown.

### Notebook-based (Pr_3 — Pr_20)
Работы выполняются в JupyterLab. Доступен ИИ-ментор (`%%ask_mentor`). Отчёт — `.ipynb` с LLM-проверкой.

## Формат отчётов

Все отчёты сохраняются в формате **Markdown** (`.md`):
- Создавайте файлы `.md` в JupyterLab или Nextcloud
- Используйте [справочник по Markdown](./MD_Instructions.md) для форматирования
- Загружайте `.md` файлы в ваш репозиторий `reports_<группа>_<номер>` в GitLab
