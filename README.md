# Интеллектуальные системы и технологии

Репозиторий содержит практические работы по курсу «Интеллектуальные системы и технологии», проводимому на кафедре [ИИСТ](https://www.npi-tu.ru/university/faculty/fitu/kafedry/?kaf=iist) в [ЮРГПУ(НПИ)](https://npi-tu.ru/). Основная цель — закрепить теоретические знания через практическую реализацию и апробацию алгоритмов машинного обучения, анализа данных и методов интеллектуальной обработки информации.

## В проекте представлены:

  - Набор практических заданий в формате Markdown файлов.
  - Иллюстративные изображения и графики для пояснения результатов.
  - bash-скрипт для установки и настройкии серверного программного обеспечения для организации учебного класса

Отдельная папка [docs/](docs/) с развернутыми методическими рекомендациями и кодом по каждому занятию.

## Ключевые практические работы
  1. [Основы Git и Github](docs/Pr_1.md)
  2. [Основы работы с технологиями контейнеризации и ботами Telegram](docs/Pr_2.md)
  3. [Знакомство с Python](docs/Pr_3.md)
  4. [Визуализация данных средствами MatplotLib. Основы](docs/Pr_4.md)
  5. [Визуализация данных средствами MatplotLib. Диаграммы](docs/Pr_5.md)
  6. [Работа с облачными системами хранения и визуализации данных](docs/Pr_6.md)
  7. [Машинное обучение. K‑Means Clustering](docs/Pr_7.md)
  8. [Машинное обучение. K-Nearest Neighbors](docs/Pr_8.md)
  9. [Машинное обучение. Density-Based Clustering](docs/Pr_9.md)
  10. [Машинное обучение. Hierarchical Clustering](docs/Pr_10.md)
  11. [Машинное обучение. Decision Trees](docs/Pr_11.md)
  12. [Машинное обучение. SVM (Support Vector Machines)](docs/Pr_12.md)
  13. [Машинное обучение. Logistic Regression with Python](docs/Pr_13.md)
  14. [Машинное обучение. Collaborative filtering](docs/Pr_14.md)
  15. [Машинное обучение. Content-based filtering](docs/Pr_15.md)
  16. [Машинное обучение. Simple Linear Regression](docs/Pr_16.md)
  17. [Машинное обучение. Multiple Linear Regression](docs/Pr_17.md)
  18. [Машинное обучение. Non Linear Regression Analysis](docs/Pr_18.md)
  19. [Машинное обучение. Классификаторы изображений](docs/Pr_19.md)
  20. [Машинное обучение. Суммаризация и классификация текстов](docs/Pr_20.md)

## Рекомендуемая программная конфигурация

[bash-скрипт](setup_jupyterhub.sh) для установки и настройкии серверного программного обеспечения для организации учебного класса предназначен для запуска в ОС Ubuntu 22.04. 
Выполняет установку всех необходимых python-библиотек, создание учетных записей пользователей (jupyter для размещение данных и 29 студентов), размещение в предполагаемых методическими рекомендациями каталогах данных. 
Для установки необходимо:
  - Создать файл setup_jupyterhub.sh (например, `nano setup_jupyterhub.sh`), вставить содержимое скрипта, сохранить.
  - Сделать файл исполнимым: `chmod +x setup_jupyterhub.sh`.
  - Запустить с правами суперпользователя: `sudo ./setup_jupyterhub.sh` 

## Планы по развитию
  - Добавить новые практики по темам нейронных сетей и глубокого обучения.
  - Расширить раздел с нейронными сетями.
  - Внедрить автотесты и CI/CD для автоматической проверки отчётов и кода.

## Ссылки
  - IBM: Git and GitHub Basics, https://www.edx.org/learn/github/ibm-git-and-github-basics
  - MITx: Introduction to Computer Science and Programming Using Python, https://www.edx.org/learn/computer-science/massachusetts-institute-of-technology-introduction-to-computer-science-and-programming-using-python
  - IBM: Python Basics for Data Science, https://www.edx.org/learn/python/ibm-python-basics-for-data-science
  - IBM: Machine Learning with Python: A Practical Introduction, https://www.edx.org/learn/machine-learning/ibm-machine-learning-with-python-a-practical-introduction
  - IBM: Analyzing Data with Python, https://www.edx.org/learn/python/ibm-analyzing-data-with-python
  - IBM: Visualizing Data with Python, https://www.edx.org/learn/data-visualization/ibm-visualizing-data-with-python
  - IBM: Data Science and Machine Learning Capstone Project, https://www.edx.org/learn/data-science/ibm-data-science-and-machine-learning-capstone-project
  - PyTorch: Training a Classifier, https://docs.pytorch.org/tutorials/beginner/blitz/cifar10_tutorial.html
  - Databricks: Large Language Models: Application through Production, https://minkj1992.github.io/llm/
  - Introduction to Machine Learning with Python, https://github.com/amueller/introduction_to_ml_with_python

## License

This project is licensed under the [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) license. See the [LICENSE](./LICENSE) file for details.
