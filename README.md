# Мультисистемный учебный комплекс с ИИ-ментором

Docker Compose-развёртывание полного учебного класса для курса «Интеллектуальные системы и технологии» с контролируемым ИИ-помощником, GitLab CI/CD автооценки и low-code платформой Langflow.

> 📚 **Полная документация — [Wiki](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki):**
> [Installation](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Installation) · [Services](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Services) · [AI-Mentor](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/AI-Mentor) · [CI/CD](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/CI-CD) · [Переоценка и смена модели](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/CI-CD-Regrade) · [Dashboard](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Dashboard) · [Langflow Pr_29–31](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Langflow) · [Usage](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Usage) · [Configuration](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Configuration) · [Troubleshooting](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Troubleshooting) · [Licensing](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Licensing)

## 📋 Содержание

- [Архитектура](#архитектура)
- [Функционал](#функционал)
- [Структура проекта](#структура-проекта)
- [Системные требования](#системные-требования)
- [Быстрый старт](#быстрый-старт)
- [Административные доступы](#административные-доступы)
- [Сервисы](#сервисы)
- [Использование студентом](#использование-студентом)
- [Использование преподавателем](#использование-преподавателем)
- [Конфигурация](#конфигурация)
- [Устранение неполадок](#устранение-неполадок)
- [Лицензирование ИИ-моделей](#лицензирование-ии-моделей)

---

## Архитектура

```
┌────────────────────────────────────────────────────────────────┐
│             HOST (Linux, 32+ GB RAM)                           │
│                                                                │
│  Внешние порты:                                                │
│  GitLab:       80 (HTTP) / 2222 (SSH)                          │
│  JupyterHub:   8000 (по умолчанию)                             │
│  Dashboard:    9000 (по умолчанию)                             │
│  Langflow:     7860 (визуальный конструктор, Pr_29–Pr_31)      │
│  Embeddings:   8021 (OpenAI-совместимый /v1/embeddings)        │
│                                                                │
│  Internal bridge network:                                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐                    │
│  │ GitLab   │ │ Jupyter  │ │  Dashboard   │                    │
│  │  :80/22  │ │  :8000   │ │   (opt.)     │                    │
│  └──────────┘ └──────────┘ └──────────────┘                    │
│        │Local auth    │Local auth    │Basic Auth               │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐                    │
│  │ GitLab   │ │  LLM     │ │  Admin       │                    │
│  │ Runner   │ │ (opt.)   │ │  Dashboard   │                    │
│  └──────────┘ └──────────┘ └──────────────┘                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐                    │
│  │ Langflow │ │ Embedd.  │ │ User-home    │                    │
│  │   :7860  │ │   :8021  │ │ volumes      │                    │
│  └──────────┘ └──────────┘ └──────────────┘                    │
│                                                                │
│  Shared Volumes:                                               │
│    /shared/data        → материалы преподавателя               │
│    /shared/student-work→ репозитории студентов                 │
│    User homes          → ~/.logs/grading_log.json              │
└────────────────────────────────────────────────────────────────┘
```

**Базовые сервисы (6):** GitLab CE, GitLab Runner, JupyterHub, Admin Dashboard, Langflow, istp-embeddings + один из трёх взаимозаменяемых LLM-профилей (`llm`, `llm-gigachat`, `llm-qwen`). Подробности — [Services](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Services).

---

## Функционал

### Для студентов

| Функция | Описание |
|---|---|
| **Саморегистрация** | Регистрация в GitLab или JupyterHub через форму Sign Up |
| **ИИ-Ментор** | Команда `%%ask_mentor` в ячейках JupyterLab |
| **Классификация запросов** | LAZY (штраф) / SMART (поощрение) |
| **Файловое хранилище** | GitLab с репозиториями и Markdown-отчётами |
| **SSH-ключи** | Генерация при первом входе, добавление в GitLab |
| **Git-репозиторий** | Личный репозиторий для каждого студента |
| **CI/CD проверка** | Автоматическая оценка отчётов (MD, ipynb, flow JSON) через LLM |

### Для преподавателя

| Функция | Описание |
|---|---|
| **Панель мониторинга** | Единая таблица: оценки + LAZY/SMART по практикам |
| **Фильтры** | По студенту, практике, дате, времени |
| **Экспорт данных** | CSV-экспорт за заданный период |
| **Lazy/Smart-списки** | Развёрнутые списки вопросов по каждой (студент, практика) |
| **Авто-оценка** | CI/CD pipeline проверяет отчёты автоматически |
| **Группы студентов** | Организация по группам (pia, ista, istb, pa) |

---

## Структура проекта

```
├── docker-compose.yml           # Оркестрация сервисов (6 базовых + 1 из 3 LLM-профилей)
├── .env.example                 # Шаблон переменных окружения
├── .env                         # Генерируется setup.sh (не коммитить)
│
├── scripts/
│   ├── setup.sh                 # Интерактивный инсталлятор
│   ├── init_gitlab.sh           # Инициализация GitLab (группы, лекторы, шаблон проекта, Runner)
│   ├── update_ci_llm_model.py   # Смена LLM-модели/timeout в .gitlab-ci.yml всех проектов
│   └── healthcheck.sh           # Проверка здоровья сервисов
│
├── jupyterhub/                  # JupyterHub + JupyterLab + nativeauthenticator + %%ask_mentor
├── llm/                         # LLM-профили: legacy / GigaChat3.1 / Qwen2.5-3B (GGUF в образах)
│
├── runner/                      # CI-оценщик → образ istp-ci:latest
│   ├── Dockerfile.python310     # Python 3.10 + nbconvert
│   └── scripts/
│       ├── auto_grade.py        # CI-оркестратор (student identity, persist в Dashboard)
│       ├── grade_md.py          # Оценка Markdown-отчёта (Pr_<N>)
│       ├── grade_notebook.py    # Оценка ноутбука через LLM
│       ├── grade_flow.py        # Детерминированная проверка flow JSON (Pr_29–31)
│       ├── debug_flow.py        # Диагностика экспорта flow (отладка имён блоков)
│       ├── practice_specs.py    # Спеки оценки: tasks/markers + вопросы (Pr_1..Pr_31)
│       ├── ideal_reports/       # Эталонные MD-отчёты (few-shot для LLM)
│       └── ideal_flows/         # Эталонные flow JSON (Pr_29–31)
│
├── dashboard/                   # Admin Dashboard (Flask + Plotly): оценки, LAZY/SMART, CSV
├── langflow/                    # Langflow 1.12.6 (учебный конструктор, Pr_29–Pr_31)
├── embeddings/                  # istp-embeddings: OpenAI-совместимый сервер эмбеддингов (CPU)
│
├── docs/                        # Методички: Pr_0 (настройка), Pr_1..Pr_28, Pr_29–31 (Langflow)
├── shared/                      # Volumes mount point (data/, student-work/)
└── README.md                    # этот файл
```

---

## Системные требования

| Компонент | Минимум | Рекомендуется |
|---|---|---|
| **ОС** | Ubuntu 22.04 LTS | Ubuntu 22.04 / 24.04 |
| **RAM** | 24 GB | 32+ GB |
| **CPU** | 4 cores | 8+ cores |
| **GPU** | Не обязательно | NVIDIA GTX 1060+ (для локальной LLM) |
| **Диск** | 50 GB | 100+ GB |
| **Docker** | 24.0+ | 27+ |
| **Docker Compose** | v2.20+ | v2.29+ |

Подробности по образам и зависимостям — [Installation](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Installation).

---

## Быстрый старт

### 1. Клонирование репозитория

```bash
git clone https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice.git
cd Intellectual-Systems-and-Technologies-Practice
```

### 2. Проверка Docker

```bash
docker --version
docker compose version
```

### 3. Запуск инсталляции

```bash
sudo chmod +x scripts/setup.sh
sudo ./scripts/setup.sh
```

Скрипт задаст:
1. Внешний адрес сервера (IP или домен)
2. Порт JupyterHub (по умолчанию: `8000`)
3. Порт Admin Dashboard (по умолчанию: `9000`)
4. LLM для ментора: OpenAI API / встроенный образ (GigaChat3.1 / Qwen2.5-3B)
5. LLM для CI/CD: OpenAI API / встроенный образ (GigaChat3.1 / Qwen2.5-3B)
6. SSH-ключ для GitLab Runner

Учебные данные не запрашиваются: `setup.sh` использует образ JupyterHub с предзагруженными данными и при необходимости обновляет Docker volumes `<repo>_shared-data`, `<repo>_hf-cache` и `<repo>_torch-cache`.

Полное описание всех шагов, ручная установка и **повторная установка с сохранением данных** — [Installation](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Installation).

### 4. Доступы

После установки скрипт выведет:

```
GitLab:       http://<IP>:80
  Root:       root / <generated password>
  Регистрация: через форму Sign up на странице входа

JupyterHub:   http://<IP>:8000
  Регистрация: через форму Sign up на странице входа

Dashboard:    http://<IP>:9000
  Admin:      admin (пароль Basic auth из credentials.env)
```

---

## Административные доступы

| Сервис | Логин | Пароль | URL |
|---|---|---|---|
| **GitLab (root)** | `root` | см. `.env` → `GITLAB_ROOT_PASSWORD` | `http://<IP>:80` |
| **JupyterHub** | любой (через форму Sign Up) | тот же, что создан при регистрации | `http://<IP>:<JUPYTERHUB_PORT>` |
| **Dashboard** | admin (Basic auth) | см. `.env` → `DASHBOARD_PASSWORD` | `http://<IP>:<DASHBOARD_PORT>` |
| **Langflow** | `admin` | см. `credentials.env` → `LANGFLOW_SUPERUSER_PASSWORD` | `http://<IP>:7860` |

> **Важно:** Все пароли генерируются при запуске `setup.sh` и хранятся в файле `.env`.
> Для просмотра паролей после установки: `cat .env | grep -E "GITLAB_ROOT_PASSWORD|LECTURER_"`

---

## Сервисы

| Сервис | Роль | Подробности |
|---|---|---|
| **GitLab CE** (80, 2222) | SCM, CI/CD, хранилище отчётов; саморегистрация; группа `students` | [Services](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Services) |
| **JupyterHub** (8000) | Ноутбуки студентов, NativeAuthenticator, изоляция `/home/{user}` | [Services](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Services) |
| **LLM** (internal 8080) | Локальный инференс (3 профиля) или внешний OpenAI-совместимый API | [Configuration](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Configuration) |
| **GitLab Runner** | Автооценка отчётов на `istp-ci:latest`, concurrency 2, job-level `timeout: 90m` | [CI/CD](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/CI-CD) |
| **Admin Dashboard** (9000) | Панель преподавателя: оценки + LAZY/SMART, CSV-экспорт | [Dashboard](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Dashboard) |
| **Langflow** (7860) | Визуальный конструктор AI-систем для Pr_29–Pr_31 | [Langflow](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Langflow) |
| **istp-embeddings** (8021) | OpenAI-совместимый `/v1/embeddings` для RAG (Pr_30) | [Langflow](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Langflow) |

---

## Использование студентом

```
1. Регистрация в JupyterHub (Sign Up) и GitLab (Sign Up, затем Settings → Password)
2. git clone http://<IP>/students/project.git (или через SSH/PAT)
3. Практика 1 (Git): fork → CLI-операции → отчёт Pr_1_<группа>_<номер>.md в reports/
4. Практики 2+: ipynb + %%ask_mentor → git push (+ .grade-trigger для оценки)
5. Пр_29–31: flow в Langflow → Export JSON + MD-отчёт → git push
```

Пошаговый алгоритм с примерами ментора — [Usage](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Usage).

---

## Использование преподавателем

```
1. Dashboard http://<IP>:9000: оценки + LAZY/SMART, фильтры, CSV-экспорт
2. GitLab → проект студента → CI/CD → Pipelines: job grade, артефакт ai_report.json
3. Логи ментора: /home/<student>/.logs/grading_log.json (или Dashboard API)
```

Детально — [Usage](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Usage). Переоценка всех отчётов и смена LLM-модели — [CI-CD-Regrade](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/CI-CD-Regrade).

---

## Конфигурация

Ключевые переменные `.env` (генерируются `setup.sh`):

| Переменная | Описание | По умолчанию |
|---|---|---|
| `JUPYTERHUB_PORT` / `DASHBOARD_PORT` | Порты JupyterHub / Dashboard | `8000` / `9000` |
| `LLM_MENTOR_TYPE` / `LLM_CI_TYPE` | `local` (контейнер) или `openai` (внешний API) | `local` |
| `LLM_MENTOR_BASE_URL` / `LLM_CI_BASE_URL` | Endpoint LLM | `http://llm:8080/v1` |
| `LLM_MENTOR_MODEL` / `LLM_CI_MODEL` | Имя модели (GGUF для local) | — |
| `GITLAB_ROOT_PASSWORD` | Пароль GitLab root | auto-generated |
| `LANGFLOW_PORT` / `EMBEDDINGS_PORT` | Порты Langflow / embeddings | `7860` / `8021` |
| `GITLAB_ADMIN_TOKEN` | Root-токен GitLab API (авто) | — |

Полная таблица и compose-профили LLM — [Configuration](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Configuration).

---

## Устранение неполадок

Три самых частых случая:

**GitLab не стартует / долгий старт после перезагрузки.** После неконтролируемого останова postgres делает crash recovery (может идти десятки минут) — контейнер убивать нельзя. В compose задан `stop_grace_period: 5m` для чистой остановки.

**Пайплайн не создаётся (400).** Проверить конфиг: `GET /api/v4/projects/:id/ci/lint`; права root в проекте (protected main требует Maintainer+ как участника); триггер по API — только JSON-телом.

**Runner не подхватывает jobs.** Смотреть `docker logs gitlab-runner` (204 на jobs/request = жив). В GitLab 18 глобальный `GET /api/v4/runners` может возвращать пустой список — это особенность API, а не сбой.

Полный справочник — [Troubleshooting](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Troubleshooting).

---

## Лицензирование ИИ-моделей

Комплекс предзагружает сторонние модели: BERT и Wav2Vec2 (Apache 2.0), Whisper (MIT), ResNet34/Mask R-CNN (BSD 3-Clause, веса — ImageNet/COCO), датасет GLUE/STS-B (CC BY 4.0). Состав подобран для академического использования в рамках практикумов. Полные условия — [Licensing](https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/wiki/Licensing).
