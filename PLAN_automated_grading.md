# План: Автоматическая оценка работ + CI/CD

## Архитектура (итоги обсуждения)

### Pr_1 — GitLab (Terminal-based)
- Студент: fork → clone → git-операции → LLM_Help.ipynb → Pr_1_<группа>_<номер>.md → push
- Проверка: Runner клонирует репозиторий → анализирует `git log` → LLM оценивает (0-5)
- Dashboard: оценка 0-5 + LAZY/SMART count (по дате занятия)

### Pr_2 — Исключена (Telegram не актуален)

### Pr_3–Pr_20 — Notebook-based
- Студент: JupyterLab → practiceN.ipynb с %%ask_mentor → push
- Проверка: Runner клонирует → grade_notebook.py → LLM оценивает (0-5)
- Dashboard: оценка 0-5 + LAZY/SMART count (по дате занятия)

---

## Что нужно сделать (9 задач)

### 1. Переделать grade_notebook.py → шкала 0-5

**Файл:** `runner/scripts/grade_notebook.py`

**Изменения:**
- Промпт LLM: вместо `score 0-100 / grade A-F` → `score 0-5`
- Промпт должен включать критерии оценки для каждой практической работы
- Результат: `{"score": 3, "feedback": "...", "issues": [...], "recommendations": [...]}`
- Формат вывода: `Оценка: 3/5`

---

### 2. Создать `grade_md.py` для оценки Markdown-отчётов (Pr_1)

**Новый файл:** `runner/scripts/grade_md.py`

**Логика:**
- Принимает `.md` файл + номер практики (1-20)
- Анализирует `git log` репозитория (через `git log --all --oneline`)
- Для Pr_1 проверяет конкретные операции:
  1. Есть ли коммиты
  2. Есть ли ветка (branch)
  3. Есть ли merge request (через GitLab API)
  4. Есть ли fork (через GitLab API)
- LLM-оценка 0-5 по критериям Pr_1:
  - 5: все операции выполнены
  - 4: выполнено с несколькими ошибками
  - 3: выполнено не полностью, но основное
  - 2: выполнено меньше половины
  - 1: выполнено меньше 20%
  - 0: не выполнялось

---

### 3. Создать шаблон `.gitlab-ci.yml` для репозитория студентов

**Новый файл:** `gitlab-custom/gitlab-ci-template.yml`

**Содержание:**
```yaml
stages:
  - grade

grade:
  stage: grade
  image: python:3.10-slim
  tags:
    - istp-runner
  before_script:
    - pip install nbformat nbconvert requests
  script:
    - python /scripts/auto_grade.py
  after_script:
    - rm -rf /tmp/runner-*  # Очистка после проверки
  artifacts:
    paths:
      - ai_report.json
    expire_in: 30 days
```

**ИЛИ** — проще: runner-скрипт, который не требует `.gitlab-ci.yml` в каждом репозитории, а запускается автоматически через GitLab CI/CD trigger.

---

### 4. Создать `auto_grade.py` — скрипт CI/CD пайплайна

**Новый файл:** `runner/scripts/auto_grade.py`

**Логика:**
1. Клонирует репозиторий студента (через GitLab API token)
2. Определяет тип работы:
   - Если есть `.md` файлы → `grade_md.py`
   - Если есть `.ipynb` файлы → `grade_notebook.py`
3. Сохраняет `ai_report.json`
4. Очищает временные файлы (rm -rf)
5. Отправляет результат в Dashboard API (или сохраняет в GitLab artifacts)

---

### 5. Добавить API-эндпоинт для приёма оценок в Dashboard

**Файл:** `dashboard/routes.py`

**Новые эндпоинты:**
- `POST /api/grade` — Runner отправляет оценку (student, practice, score, feedback, timestamp)
- `GET /api/grades` — Dashboard показывает оценки студентов
- `GET /api/summary` — обновляется для inclusion of grades

**Структура grade-записи:**
```json
{
  "student": "student_pia_01",
  "practice": 1,
  "score": 4,
  "feedback": "...",
  "lazy_count": 2,
  "smart_count": 5,
  "timestamp": "2026-08-09T10:30:00"
}
```

---

### 6. Обновить Dashboard UI для отображения оценок

**Файл:** `dashboard/templates/dashboard.html`

**Добавить:**
- Таблица оценок по студентам (практика | оценка | LAZY | SMART)
- Фильтр по номеру практики (select: 1, 3, 4, ..., 20)
- Фильтр по дате (уже есть)
- Экспорт оценок в CSV
- Отдельный блок "Оценки студентов" над таблицей логов ментора

---

### 7. Обновить Pr_1.md — методические указания

**Файл:** `docs/Pr_1.md`

**Изменения:**
- Убрать fork через браузер (студент делает fork через GitLab UI)
- Добавить шаги:
  1. Fork проекта `students/project`
  2. Clone своего fork
  3. Создание ветки, merge request, commit
  4. Создание `LLM_Help.ipynb` с вопросами к ментору
  5. Создание `Pr_1_<группа>_<номер>.md` отчёта
  6. `git push`
- Обновить критерии оценки (0-5)
- Убрать fork через браузер — оставить fork через GitLab UI

---

### 8. Обновить Pr_2.md — исключить Telegram, добавить Docker

**Файл:** `docs/Pr_2.md`

**Изменения:**
- Убрать Telegram бота
- Добавить создание Docker-контейнера с Python-приложением:
  1. `Dockerfile` для Python-приложения
  2. `docker build`
  3. `docker run`
  4. `docker logs`
- `LLM_Help.ipynb` с вопросами к ментору по Docker
- `Pr_2_<группа>_<номер>.md` отчёт
- `git push`

---

### 9. Обновить init.sh — добавить шаблон CI/CD в `students/project`

**Файл:** `keycloak-init/init.sh`

**Добавить:**
- При создании репозитория `students/project` добавить:
  - `.gitlab-ci.yml` (шаблон CI/CD пайплайна)
  - `docs/Pr_1.md ... Pr_20.md` (методички)

---

## Порядок реализации

1. **grade_notebook.py** (0-5) → базовая оценка
2. **grade_md.py** → оценка Pr_1
3. **auto_grade.py** → CI/CD пайплайн
4. **Dashboard API** → приём оценок
5. **Dashboard UI** → отображение оценок
6. **Pr_1.md** → обновить методичку
7. **Pr_2.md** → исключить Telegram
8. **init.sh** → шаблон CI/CD

---

## Технические детали

### Локация файлов
```
runner/scripts/
├── grade_notebook.py    ← обновить (0-5)
├── grade_md.py          ← новый (для Pr_1)
└── auto_grade.py        ← новый (CI/CD пайплайн)

dashboard/
├── routes.py            ← обновить (API для оценок)
└── templates/
    └── dashboard.html   ← обновить (UI оценок)

docs/
├── Pr_1.md              ← обновить
└── Pr_2.md              ← обновить

gitlab-custom/
└── gitlab-ci-template.yml  ← новый (шаблон)
```

### Очистка после проверки
Runner должен удалять клонированный репозиторий после проверки:
```bash
rm -rf /tmp/runner-*
```
или через `gitlab-runner` cleanup.

### Логирование оценок
Оценки хранятся в одном месте:
```
/shared/data/grades/
├── student_pia_01.json
├── student_pia_02.json
└── ...
```
или в базе данных Dashboard (если будет добавлена).

### Фильтрация по дате
Dashboard фильтрует по `timestamp` из `grading_log.json` (дата занятия). Оценки привязываются к этой же дате.
