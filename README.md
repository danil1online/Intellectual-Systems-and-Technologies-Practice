# Мультисистемный учебный комплекс с ИИ-ментором

Docker Compose-развёртывание полного учебного класса для курса «Интеллектуальные системы и технологии» с контролируемым ИИ-помощником, GitLab CI/CD и единой системой авторизации.

## 📋 Содержание

- [Архитектура](#архитектура)
- [Функционал](#функционал)
- [Структура проекта](#структура-проекта)
- [Зависимости](#зависимости)
- [Быстрый старт](#быстрый-старт)
- [Инсталляция](#инсталляция)
- [Административные доступы](#административные-доступы)
- [Архитектура сервисов](#архитектура-сервисов)
- [ИИ-Ментор](#ии-ментор)
- [Авторизация](#авторизация)
- [GitLab CI/CD](#gitlab-cicd)
- [Admin Dashboard](#admin-dashboard)
- [Использование студентом](#использование-студентом)
- [Использование преподавателем](#использование-преподавателем)
- [Конфигурация](#конфигурация)
- [Устранение неполадок](#устранение-неполадок)

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
│  Registry:     5050 (Docker Container Registry)                │
│                                                                │
│  Internal bridge network:                                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐                    │
│  │ GitLab   │ │ Jupyter  │ │  Dashboard   │                    │
│  │  :80/22  │ │  :8000   │ │   (opt.)     │                    │
│  └──────────┘ └──────────┘ └──────────────┘                    │
│        │Local auth    │Local auth    │Basic Auth               │
│                                                                │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐                    │
│  │ GitLab   │ │  LLM     │ │  Admin       │                    │
│  │ Runner   │ │ (opt.)   │ │  Dashboard   │                    │
│  └──────────┘ └──────────┘ └──────────────┘                    │
│  ┌──────────┐                                                  │
│  │ Jupyter  │ │ User-home volumes (per-user)                   │
│  └──────────┘                                                  │
│  ┌──────────┐                                                  │
│  │ Registry │ │ :5050 (Docker images для CI/CD)                │
│  └──────────┘                                                  │
│                                                                │
│  Shared Volumes:                                               │
│    /shared/data        → материалы преподавателя               │
│    /shared/student-work→ репозитории студентов                 │
│    User homes          → ~/.logs/grading_log.json              │
└────────────────────────────────────────────────────────────────┘
```

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
| **CI/CD проверка** | Автоматическая оценка ipynb-отчётов через LLM |

### Для преподавателя

| Функция | Описание |
|---|---|
| **Панель мониторинга** | Единая таблица: оценки + LAZY/SMART по практикам |
| **Фильтры** | По студенту, практике, дате, времени |
| **Экспорт данных** | CSV-экспорт за заданный период |
| **Lazy/Smart-списки** | Развёрнутые списки вопросов по каждой (студент, практика) |
| **Авто-оценка** | CI/CD pipeline проверяет ноутбуки автоматически |
| **Группы студентов** | Организация по группам (pia, ista, istb, pa) |

---

## Структура проекта

```
├── docker-compose.yml           # Оркестрация сервисов (8 базовых + 1 из 3 LLM-профилей)
├── .env.example                 # Шаблон переменных окружения
├── .env                         # Генерируется setup.sh (не коммитить)
│
├── scripts/
│   ├── setup.sh                 # Интерактивный инсталлятор
│   ├── init_gitlab.sh           # Инициализация GitLab
│   └── healthcheck.sh           # Проверка здоровья сервисов
│
├── jupyterhub/
│   ├── Dockerfile               # JupyterHub + JupyterLab + nativeauthenticator
│   ├── jupyterhub_config.py     # NativeAuth, LocalProcessSpawner, hooks
│   ├── startup/
│   │   └── 00_mentor.py         # %%ask_mentor magic
│   ├── persona_mentor.py        # @mentor persona (MCP)
│   ├── jupyter_ai_config.json   # Конфигурация jupyter-ai
│   └── startup-hooks/
│       └── generate_ssh_keys.py # SSH-генерация при первом входе
│
├── llm/
│   ├── Dockerfile               # Legacy: ghcr.io/ggml-org/llama.cpp:server-cuda12
│   ├── Dockerfile.gigachat      # GigaChat3.1-10B-A1.8B (~7.5 ГБ, встроенная модель)
│   ├── Dockerfile.qwen          # Qwen2.5-3B-Instruct (~3.5 ГБ, встроенная модель)
│   ├── start-server.sh          # Запуск llama-server
│   ├── GigaChat3.1-10B-A1.8B-q4_K_M.gguf
│   └── qwen2.5-3b-instruct-q4_k_m.gguf
│
├── runner/
│   ├── Dockerfile.python310     # Python 3.10 + nbconvert → образ istp-ci:latest
│   ├── entrypoint.sh            # SSH + runner
│   └── scripts/
│       ├── auto_grade.py        # CI-оркестратор (student identity, persist в Dashboard)
│       ├── grade_md.py          # Оценка Markdown-отчёта (Pr_<N>)
│       └── grade_notebook.py    # Оценка ноутбука через LLM
│
├── dashboard/
│   ├── Dockerfile               # Flask + Plotly
│   ├── app.py                   # Flask приложение
│   ├── routes.py                # REST API: results, students, logs, stats, export
│   ├── models.py                # legacy (не импортируется; кэш — in-memory в routes.py)
│   ├── templates/
│   │   └── dashboard.html      # Единая таблица (результаты + Lazy/Smart-списки)
│   └── static/                  # CSS/JS (по желанию)
│

├── docs/
│   ├── README.md                # Индекс практических работ
│   ├── MD_Instructions.md       # Справочник по Markdown
│   ├── Pr_0.md                  # Предварительная настройка комплекса
│   ├── Pr_1.md                  # Основы Git и GitLab
│   ├── Pr_2.md — Pr_21.md       # Практические (Python, ML, визуализация, MAX)
│
├── shared/                      # Volumes mount point
│   ├── data/                    # Материалы преподавателя
│   └── student-work/            # Репозитории студентов
│
└── README.md                    # этот файл
```

---

## Зависимости

### Системные требования

| Компонент | Минимум | Рекомендуется |
|---|---|---|
| **ОС** | Ubuntu 22.04 LTS | Ubuntu 22.04 / 24.04 |
| **RAM** | 24 GB | 32+ GB |
| **CPU** | 4 cores | 8+ cores |
| **GPU** | Не обязательно | NVIDIA GTX 1060+ (для локальной LLM) |
| **Диск** | 50 GB | 100+ GB |
| **Docker** | 24.0+ | 27+ |
| **Docker Compose** | v2.20+ | v2.29+ |

### Зависимости Docker-образов

#### GitLab CE
```
Build: ./gitlab-custom (gitlab/gitlab-ce:18.10.4-ce.0 + patch)
RAM: ~4 GB
Ports: 80, 2222
```

#### GitLab Runner
```
Image: gitlab/gitlab-runner:alpine-v18.10.1
RAM: ~100 MB
Mount: /var/run/docker.sock
```

#### JupyterHub
```
Image: ghcr.io/danil1online/istp-jupyterhub:latest (base: python:3.10-slim)
Build: jupyterhub/Dockerfile (HF_TOKEN BuildKit secret, data.zip, Canada.xlsx)
Packages: jupyterhub, jupyterlab, nativeauthenticator, jupyter-ai
RAM: ~500 MB на спавн
```

#### LLM (опционально, 3 взаимозаменяемых профиля)
```
Профиль 1 — legacy (local-llm):
  Base: ghcr.io/ggml-org/llama.cpp:server-cuda12
  Build: Dockerfile → start-server.sh, initialize.sh
  Volume: /models (GGUF модель)
  RAM: ~2 GB + VRAM

Профиль 2 — GigaChat (local-llm-gigachat):
  Image: istp-llm-gigachat:latest (~7.5 ГБ)
  Model: GigaChat3.1-10B-A1.8B (встроена в образ)
  RAM: ~2 GB + VRAM

Профиль 3 — Qwen (local-llm-qwen):
  Image: istp-llm-qwen:latest (~3.5 ГБ)
  Model: Qwen2.5-3B-Instruct (встроена в образ)
  RAM: ~2 GB + VRAM
```

#### Admin Dashboard
```
Base: python:3.10-slim
Packages: flask, plotly, requests, python-dotenv, oauthenticator
RAM: ~50 MB
```

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

### 5. Административные доступы

| Сервис | Логин | Пароль | URL |
|---|---|---|---|
| **GitLab (root)** | `root` | см. `.env` → `GITLAB_ROOT_PASSWORD` | `http://<IP>:80` |
| **JupyterHub** | любой (через форму Sign Up) | тот же, что создан при регистрации | `http://<IP>:<JUPYTERHUB_PORT>` |
| **Dashboard** | admin (Basic auth) | см. `.env` → `DASHBOARD_PASSWORD` | `http://<IP>:<DASHBOARD_PORT>` |

> **Важно:** Все пароли генерируются при запуске `setup.sh` и хранятся в файле `.env`.
> Для просмотра паролей после установки: `cat .env | grep -E "GITLAB_ROOT_PASSWORD|LECTURER_"`

### 6. Добавление SSH-ключа для GitLab Runner

```bash
# Скопируйте публичный ключ
cat shared/data/runner-keys/runner_ed25519.pub

# Добавьте в GitLab:
# Settings → Repository → Deploy Keys → Add key
```

---

## Сборка JupyterHub-образа (GHCR)

JupyterHub-образ собирается отдельно. `scripts/setup.sh` **не собирает** его из исходников — скрипт использует prebuilt-образ из GHCR или локальный `istp-jupyterhub:latest`, если он уже есть.

Перед сборкой в `jupyterhub/` должны быть:

- `jupyterhub/data.zip`
- `jupyterhub/data/Canada.xlsx`
- `jupyterhub/data/PennFudanPed/` для `Pr_23`

Если файлов нет, можно подготовить так:

```bash
cd jupyterhub
cp ../data.zip ./data.zip
mkdir -p data
curl -fsSL -o data/Canada.xlsx \
  "https://s3-api.us-geo.objectstorage.softlayer.net/cf-courses-data/CognitiveClass/DV0101EN/labs/Data_Files/Canada.xlsx"
mkdir -p data/PennFudanPed
python3 -m zipfile -e ../PennFudanPed.zip data/PennFudanPed/
```

Сборка:

```bash
cd jupyterhub

# HF_TOKEN используется Dockerfile для предзагрузки HF-моделей/датасетов
export HF_TOKEN=hf_...

docker build \
  -f Dockerfile \
  --secret id=HF_TOKEN,env=HF_TOKEN \
  -t ghcr.io/danil1online/istp-jupyterhub:latest \
  .

# Локальный tag нужен setup.sh, чтобы использовать данные и кэши из образа
docker tag ghcr.io/danil1online/istp-jupyterhub:latest istp-jupyterhub:latest
```

Публикация:

```bash
docker login ghcr.io
docker push ghcr.io/danil1online/istp-jupyterhub:latest
```

После push образ доступен `scripts/setup.sh` при установке на сервере.

Важно:
- новый образ стал заметно больше, чем раньше: в него добавлены MNIST/FashionMNIST, LibriSpeech subset, 20-Newsgroups, TensorFlow MNIST, InceptionV3, HF-модели/датасеты и PennFudanPed;
- сборка занимает больше времени из-за автоматической предзагрузки ресурсов;
- `setup.sh` обновляет volumes `<repo>_shared-data`, `<repo>_hf-cache` и `<repo>_torch-cache` по version markers и при старте JupyterHub заполняет их из нового образа.

---

## Инсталляция

### Интерактивный setup.sh

Скрипт `scripts/setup.sh` выполняет последовательно:

```
ШАГ 0/11: Проверка портов и автоопределение сетевых параметров
  → Определение локального IP, VPN IP, подсети, шлюза

ШАГ 1/11: Внешний адрес сервера
  → http://<IP_или_домен>
  → Рекомендуется VPN IP при наличии VPN (amnezia WireGuard)

ШАГ 2/11: Порты сервисов
  → JupyterHub (по умолчанию 8000)
  → Dashboard (по умолчанию 9000)

ШАГ 3/11: LLM для ИИ-Ментора
  → Выбор: OpenAI API / Локальный контейнер
  → Если OpenAI: endpoint IP:port + API ключ + имя модели
  → Если локальный: выбор встроенного образа
    · [1] GigaChat3.1-10B-A1.8B (~6.1 ГБ, ~7.5 ГБ образ)
    · [2] Qwen2.5-3B-Instruct (~2.0 ГБ, ~3.5 ГБ образ)
  → Модель встроена в образ (не нужен путь к .gguf)

ШАГ 4/11: LLM для CI/CD
  → Выбор: OpenAI API / Локальный контейнер
  → Если ментор тоже локальный: предупреждение, один LLM-контейнер для обоих
  → Если ментор OpenAI, CI/CD локальный: выбор встроенного образа
    · [1] GigaChat3.1-10B-A1.8B (~6.1 ГБ, ~7.5 ГБ образ)
    · [2] Qwen2.5-3B-Instruct (~2.0 ГБ, ~3.5 ГБ образ)
  → Если OpenAI: endpoint IP:port + API ключ + имя модели

ШАГ 5/11: SSH-ключ для GitLab Runner
  → Генерация ED25519 ключа
  → Сохранение в shared/data/runner-keys/

ШАГ 6/11: Генерация паролей
   → GitLab root, Dashboard, JupyterHub API

ШАГ 7/11: Настройка iptables DNAT
  → Перенаправление запросов с внешнего IP на localhost (для доступа с самого сервера)

ШАГ 8/11: Генерация .env
  → Запись всех конфигураций в .env файл

ШАГ 9/11: Очистка и запуск
  → Очистка предыдущих данных сервисов
  → Удаление Docker томов (кроме llm-models)

ШАГ 10/11: Предзагрузка Docker-образов
  → Загрузка базовых образов (GitLab, Runner, Registry, Python)
  → Загрузка JupyterHub prebuilt-образа из GHCR или использование локального `istp-jupyterhub:latest`
  → Проверка встроенных LLM-образов (GigaChat3.1 / Qwen2.5-3B)
  → Если образ не найден — предлагается команда ручной сборки

ШАГ 11/11: Запуск сервисов
  → docker compose up -d
   → Проверка модели в Docker volume
   → Healthcheck GitLab
   → Инициализация GitLab (группа, админ)
   → Инициализация GitLab (группа, админ)
   → Регистрация GitLab Runner
```

### Ручная установка

```bash
# 1. Скопируйте шаблон
cp .env.example .env

# 2. Отредактируйте .env
nano .env

# 3. Поднимите сервисы
docker compose up -d gitlab admin-dashboard
# Для локальной LLM (выберите ОДИН профиль):
docker compose --profile local-llm-gigachat up -d llm-gigachat
# или
docker compose --profile local-llm-qwen up -d llm-qwen
# legacy-профиль (требует GGUF модель в volume):
# docker compose --profile local-llm up -d llm

# 4. Дождитесь готовности
sleep 300
docker compose up -d jupyterhub

# 5. Инициализация
bash scripts/init_gitlab.sh

# 6. Регистрация Runner
docker exec -it gitlab-runner gitlab-runner register \
  --url http://gitlab:80 \
  --token <registration-token> \
  --executor docker \
  --docker-image istp-ci:latest \
  --tag-list istp-runner
```

---

## Архитектура сервисов

### 1. GitLab CE

```yaml
Build: ./gitlab-custom   # FROM gitlab/gitlab-ce:18.10.4-ce.0 + patch (убран prometheus-client-mmap)
Ports: 80 (HTTP), 2222 (SSH)
Volumes: gitlab-config, gitlab-logs, gitlab-data
```

**Роль:** SCM, CI/CD, файловое хранилище отчётов.

**Авторизация:** Встроенная саморегистрация (форма Sign up на странице входа).

**Группы:** `students` — для всех студенческих проектов.

**SSH-порты:** `git@gitlab:2222` для SSH-доступа.

### 2. JupyterHub

```yaml
Image: ghcr.io/danil1online/istp-jupyterhub:latest   # prebuilt; сборка описана в разделе “Сборка JupyterHub-образа”
Port: 8000 (по умолчанию)
Auth: NativeAuthenticator (саморегистрация)
Spawner: LocalProcessSpawner
```

**Ключевые компоненты:**
- **NativeAuthenticator** — саморегистрация пользователей, хранение паролей в БД
- **open_signup = True** — регистрация без одобрения администратора
- **LocalProcessSpawner** — создание отдельного Linux-пользователя и процесса для каждого студента
- **pre_spawn_hook** — создание системного пользователя, копирование шаблонов `.ipynb`, генерация SSH-ключей
- **Изоляция** — каждый студент имеет собственный `/home/{username}` с собственными правами

### 3. LLM (опционально, 3 взаимозаменяемых профиля)

**Профиль A — legacy (local-llm)**
```yaml
Build: ./llm (ghcr.io/ggml-org/llama.cpp:server-cuda12)
Port: 8080 (internal only, expose)
Volume: llm-models:/models
Model: model.gguf (загружается из volume)
Args: -ngl 99 -c 65536
```

**Профиль B — GigaChat (local-llm-gigachat)**
```yaml
Image: istp-llm-gigachat:latest (~7.5 ГБ)
Port: 8080 (internal only, expose)
Model: GigaChat3.1-10B-A1.8B-q4_K_M.gguf (встроена в образ, → /models/model.gguf)
Args: /usr/local/bin/start-server.sh (llama-server -ngl 99 -c 65536)
```

**Профиль C — Qwen (local-llm-qwen)**
```yaml
Image: istp-llm-qwen:latest (~3.5 ГБ)
Port: 8080 (internal only, expose)
Model: qwen2.5-3b-instruct-q4_k_m.gguf (встроена в образ, → /models/model.gguf)
Args: /usr/local/bin/start-server.sh (llama-server -ngl 99 -c 65536)
```

**Роль:** Локальный инференс LLM через OpenAI-совместимый API. Профили B и C взаимозаменяемы — используется только один образ с встроенной моделью.

**API Endpoints:**
```
POST /v1/chat/completions
POST /v1/embeddings
GET  /v1/models
```

### 4. GitLab Runner

```yaml
Image: gitlab/gitlab-runner:alpine-v18.10.1
Docker (job): istp-ci:latest   # собран из runner/Dockerfile.python310 (Python 3.10 + скрипты)
Tags: istp-runner
```

**Роль:** CI/CD runner для авто-оценки. Image job'а — `istp-ci:latest` (`auto_grade.py` + `grade_md.py` + `grade_notebook.py` уже внутри, `pip install` в job не требуется).

**Пайплайн:**
```yaml
stages:
  - grade

grade:
  stage: grade
  tags:
    - istp-runner
  variables:
    GIT_STRATEGY: none
    LLM_CI_BASE_URL: "<из .env>"
    LLM_CI_API_KEY: "<из .env>"
    LLM_CI_MODEL: "<из .env>"
  before_script:
    - cd /
    - rm -rf /builds/${CI_PROJECT_PATH}
    - git clone --depth 20 http://job_token:${CI_JOB_TOKEN}@gitlab:80/${CI_PROJECT_PATH}.git /builds/${CI_PROJECT_PATH}
    - cd /builds/${CI_PROJECT_PATH}
  script:
    - python /runner/scripts/auto_grade.py
  after_script:
    - rm -rf /tmp/runner-*
  artifacts:
    paths:
      - ai_report.json
    expire_in: 30 days
  only:
    - main
```

**Запуск оценки:** CI запускается на каждый push в `main`. Оценка срабатывает только при наличии файла `.grade-trigger` в репозитории — студенты создают его вручную в финальном действии каждой работы. Это предотвращает ложные оценки на промежуточных push. Job выполняется на образе `istp-ci:latest` (склонирование через `job_token`, `GIT_STRATEGY: none`).

### 5. Docker Registry

```yaml
Image: registry:2
Port: 5050 (external)
```

**Роль:** Standalone Docker Registry для хранения образов. Отдельный сервис, не встроенный в GitLab.

### 6. Admin Dashboard

```yaml
Build: ./dashboard (Flask, python:3.10-slim)
Port: 9000
Refresh: ручная кнопка «↻ Обновить» (re-fetch на клиенте)
```

**API Endpoints:**
| Эндпоинт | Описание |
|---|---|
| `GET /` | HTML дашборд (единая таблица) |
| `GET /health` | Health check (без аутентификации) |
| `GET /logout` | Выход |
| `GET /api/results` | **Основной** — оценки + Lazy/Smart по каждой практике |
| `GET /api/students` | Список идентификаторов студентов |
| `GET /api/logs` | Логи с фильтрацией |
| `GET /api/stats` | LAZY/SMART ratio по студентам |
| `GET /api/summary` | Общая сводка |
| `GET /api/export` | CSV-экспорт объединённой таблицы (`istp_results_<дата>.csv`) |
| `GET /api/grades` | Оценки студентов (0-5) |
| `POST /api/grade` | CI отправляет оценку → `/home/<user>/.grades/pr_<N>.json` |
| `GET /api/gitlab/groups` | Группы GitLab |
| `GET /api/gitlab/projects` | Проекты GitLab |
| `GET /api/gitlab/stats` | Сводка GitLab |

**Фильтры:**
- По студенту (`?student=<namespace>`)
- По практике (`?practice=Pr_7`)
- По дате (`?date_from=2025-09-01&date_to=2025-12-31`)
- По времени дня (`?time_from=09:00&time_to=12:00`)

---

## ИИ-Ментор

### Магическая команда `%%ask_mentor`

```python
%%ask_mentor
Я пытаюсь написать цикл для сортировки, вот мой код:
def sort_list(arr):
    for i in range(len(arr)+1):
        min_idx = i
        ...
Почему возникает IndexError?
```

### Как работает

```
Студент → %%ask_mentor → LLM → Классификация
                        │     ├─ LAZY (штраф)
                        │     └─ SMART (поощрение)
                        │
                        ├→ /home/{user}/.logs/grading_log.json
                        └→ Ответ студенту
```

### Системный промпт ментора

```python
SYSTEM_PROMPT = """Ты — строгий ментор по программированию.
Классифицируй запрос студента:
1. "LAZY": просит готовый код без усилий.
2. "SMART": размышляет, прикрепляет свой ошибочный код.
Отвечай СТРОГО в формате JSON:
{"category": "LAZY"|"SMART", "penalty": true|false, 
 "reason": "...", "assistant_response": "..."}"""
```

### Лог-файл (JSON Lines)

```json
{"timestamp": "2025-09-15T14:30:00", "student": "student_pia_01", "prompt": "...", "category": "SMART", "penalty": false, "reason": "Студент приложил свой код и спросил про ошибку"}
{"timestamp": "2025-09-15T14:35:00", "student": "student_pia_01", "prompt": "...", "category": "LAZY", "penalty": true, "reason": "Просит написать весь код"}
```

### AI Persona @mentor

Помимо ячейковой магии, студенты могут использовать чат Jupyter-AI с персонажем:

```
@mentor Как мне решить задачу 3?
```

Персона регистрируется через `persona_mentor.py` с жёстко заданным системным промптом.

### Конфигурация LLM

Через переменные окружения в `.env`:

```bash
# Для ментора
LLM_MENTOR_TYPE=local           # или "openai"
LLM_MENTOR_BASE_URL=http://llm:8080/v1
LLM_MENTOR_API_KEY=local-api-key

# Для CI/CD
LLM_CI_TYPE=local
LLM_CI_BASE_URL=http://llm:8080/v1
LLM_CI_API_KEY=local-api-key
```

---

## Авторизация

### Схема аутентификации

```
GitLab          JupyterHub          Dashboard
(Sign Up)       (NativeAuth)        (Basic Auth)
    │               │                    │
    └─── Независимые учётные записи ──────┘
```

### Регистрация

1. Студент регистрируется в GitLab через форму Sign Up на `/users/sign_up`
2. Студент регистрируется в JupyterHub через форму Sign Up на `/hub/signup`
3. **NativeAuthenticator** создаёт учётку с паролем в SQLite БД JupyterHub
4. **pre_spawn_hook** создаёт системного пользователя Linux, копирует шаблоны `.ipynb`, генерирует SSH-ключ
5. GitLab создаёт пользователя при регистрации (локальная учётная запись)

### Изоляция

- Каждый студент имеет отдельный Linux-пользователь в контейнере JupyterHub
- Домашняя директория `/home/{username}` с собственными правами (755)
- Данные других студентов недоступны — только свои и общие `/shared/data` (только чтение)
- Сбор данных для Dashboard: логи — в `/home/{username}/.logs/grading_log.json`, оценки — в `/home/{username}/.grades/pr_<N>.json`; Dashboard читает оба

### Fallback

**Нет fallback** — при недоступности JupyterHub студенты не смогут войти. Рекомендуется:
- Мониторинг через healthcheck
- Регулярные бэкапы Docker volumes (`user-homes`, `jupyterhub-data`)

---

## GitLab CI/CD

### Структура пайплайна

```
┌─────────────────────────────────────────────┐
│  Студент загружает notebook.ipynb в GitLab  │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
          ┌────────────────┐
          │  CI/CD Trigger │
          └───────┬────────┘
                  │
                  ▼
          ┌────────────────┐
          │  Runner Job    │
          │  1. Clone      │
          │  2. Execute    │
          │  3. Grade      │
          │  4. Artifact   │
          └───────┬────────┘
                  │
                  ▼
          ┌────────────────┐
          │  LLM Review    │
          │  AI Report     │
          └────────────────┘
```

### .gitlab-ci.yml (студенческий)

```yaml
stages:
  - grade

grade:
  stage: grade
  tags:
    - istp-runner
  variables:
    GIT_STRATEGY: none
    LLM_CI_BASE_URL: "<из .env>"
    LLM_CI_API_KEY: "<из .env>"
    LLM_CI_MODEL: "<из .env>"
  before_script:
    - cd /
    - rm -rf /builds/${CI_PROJECT_PATH}
    - git clone --depth 20 http://job_token:${CI_JOB_TOKEN}@gitlab:80/${CI_PROJECT_PATH}.git /builds/${CI_PROJECT_PATH}
    - cd /builds/${CI_PROJECT_PATH}
  script:
    - python /runner/scripts/auto_grade.py
  after_script:
    - rm -rf /tmp/runner-*
  artifacts:
    paths:
      - ai_report.json
    expire_in: 30 days
  only:
    - main
```

### Оценка ноутбука

`grade_notebook.py` проверяет:
1. **executes** — выполняется ли код без ошибок
2. **has_explanation** — есть ли поясняющие ячейки
3. **score** — оценка 0-5
4. **feedback** — детальный отзыв
5. **issues** — список проблем
6. **recommendations** — рекомендации

### Оценка Markdown-отчёта (Pr_1)

`grade_md.py` проверяет:
1. **git log** — наличие коммитов, веток, merge
2. **Чеклист Pr_1** — branch, checkout, add, commit, revert, merge, push
3. **score** — оценка 0-5

### Auto-grade (CI/CD пайплайн)

`auto_grade.py` — запускается job'ом на `istp-ci:latest` при push в `main`:
1. Проверяет наличие `.grade-trigger` (иначе — skip)
2. **Student identity** = `CI_PROJECT_NAMESPACE` (fallback: `STUDENT_ID` → `CI_PROJECT_NAMESPACE` → `CI_PROJECT`/basename)
3. Собирает deliverables `Pr_<N>_*.{md,ipynb}` (N=1..21); требования — из `docs/Pr_<N>.md`
4. Для каждой практики запускает `grade_md.py` / `grade_notebook.py` (score 0-5)
5. **Persist**: `POST /api/grade` → Dashboard пишет `/home/<student>/.grades/pr_<N>.json`
6. Debug-артефакт `ai_report.json` (в artifacts job'а)

> 💡 Оценка запускается только при наличии `.grade-trigger` — студенты пушат промежуточные изменения без нагрузки на CI.

### Шаблон проекта

При создании группы `students` автоматически создаётся шаблонный проект `project` со структурой: `docs/`, `notebooks/`, `reports/`.

### Docker Registry

Система включает standalone Docker Registry на порту `5050` для хранения образов. Отдельный сервис, не встроенный в GitLab.

```bash
# Авторизация в registry
docker login http://<server-ip>:5050

# Push образа
docker tag my-app <server-ip>:5050/my-app:latest
docker push <server-ip>:5050/my-app:latest

# Pull образа
docker pull <server-ip>:5050/my-app:latest
```

Registry доступен по адресу `http://<server-ip>:5050` (порт настраивается через `REGISTRY_PORT` в `.env`).

---

## Admin Dashboard

### Интерфейс

```
🎓 Панель преподавателя — Результаты и мониторинг                       [↻ Обновить]
──────────────────────────────────────────────────────────────────────────────────────────
Фильтры: [Студент ▼] [Практика ▼] [от-дата] [до-дата] [от-время] [до-время]
──────────────────────────────────────────────────────────────────────────────────────────
Студент (Имя Фамилия)                Прак   Оценка   #Lazy  #Smart   Время отчёта
  gitlab: <ns> · jupyter: <user>     Pr_1      2/5      12       7        17:34
  ├─ Lazy-Список    (свёрнут, раскрывается по клику)
  └─ Smart-Список   (свёрнут, раскрывается по клику)
──────────────────────────────────────────────────────────────────────────────────────────
Одна строка на (студент, практику); Lazy/Smart-вопросы — раскрывающиеся списки.
```

### Обновление

- Ручной `↻ Обновить` — ре-fetch списка через `/api/results`
- Авто-обновления по таймеру нет

### API эндпоинты

```bash
# Основной запрос — объединённая таблица (оценки + Lazy/Smart)
curl "http://<IP>:9000/api/results?student=<ns>&practice=Pr_7"

# Список студентов
curl http://<IP>:9000/api/students

# CSV-экспорт объединённой таблицы
curl -O "http://<IP>:9000/api/export?date_from=2025-09-01"

# Логи / статистика / сводка (legacy-эндпоинты)
curl http://<IP>:9000/api/stats
curl http://<IP>:9000/api/summary
```

---

## Использование студентом

### Пошаговый алгоритм

```
Шаг 1. Регистрация
  └→ Открыть JupyterHub: http://<IP>:8000
  └→ Нажать "Sign Up" → Register → student_<группа>_<номер>
  └→ Войти с теми же данными

Шаг 2. Пароль для Git-клиента
  └→ Открыть GitLab: http://<IP>
  └→ Зарегистрироваться через форму Sign up (или войти через JupyterHub если логин совпадает)
  └→ GitLab → Settings (иконка профиля) → Password
  └→ Установить пароль
  └→ Теперь git clone/push/pull по HTTP работает

Шаг 3. Клонирование проекта
  └→ Терминал JupyterLab: git clone http://<IP>/students/project.git
  └→ Или: git clone https://oauth2:<PAT>@<IP>/students/project.git

Шаг 4. SSH-ключ (опционально)
  └→ JupyterLab Terminal → ssh-keygen -t ed25519 -C student@pc
  └→ GitLab → Settings → SSH Keys → добавить ключ
  └→ Использовать: git clone git@gitlab.<IP>:students/project.git

Шаг 5. Практическая 1 (Git)
  └→ Fork students/project → clone → CLI-операции
  └→ Отчёт: Pr_1_<группа>_<номер>.md → reports/ → git push
  └→ LLM_Help.ipynb → reports/practice1/

Шаг 6. Практические 2+ (ipynb)
  ├── ИИ-Ментор: %%ask_mentor в ячейках
  ├── Отчёт: practiceN.ipynb → git push
  └── CI/CD: Runner автоматически оценивает (0-5)
```

### Пример работы с ИИ-Ментором

```python
# SMART запрос (поощрение)
%%ask_mentor
Вот мой код сортировки:
def bubble_sort(arr):
    n = len(arr)
    for i in range(n):
        for j in range(0, n-i-1):
            if arr[j] > arr[j+1]:
                arr[j], arr[j+1] = arr[j+1], arr[j]
    return arr
# Правильно ли я реализовал сложность O(n²)?

# Результат:
# 🤖 Ментор: Отлично, что вы приложили рабочий код!
# Да, это корректная реализация пузырьковой сортировки со сложностью O(n²).
# ✅ Запрос классифицирован как SMART — правильное использование ИИ!

# LAZY запрос (штраф)
%%ask_mentor
Напиши мне функцию сортировки QuickSort

# Результат:
# 🤖 Ментор: Я не буду писать за вас. Попробуйте реализовать
# сами. Подсказка: QuickSort использует принцип "разделяй и властвуй".
# ⚠️ Системой зафиксирован LAZY-запрос. Баллы могут быть снижены.
```

---

## Использование преподавателем

### Мониторинг в реальном времени

1. Открыть Dashboard: `http://<server-ip>:9000`
2. Смотреть LAZY/SMART ratio по студентам
3. Фильтровать по студенту, практике, дате, времени
4. Экспортировать CSV для отчётов

### Проверка CI/CD

1. Открыть проект студента в GitLab
2. Перейти в **CI/CD → Pipelines**
3. Посмотреть результат `ai_review`
4. Скачать артефакт `ai_report.json`

### Просмотр логов

```bash
# Все запросы конкретного студента (персональный файл)
tail -f /home/student_pia_01/.logs/grading_log.json

# LAZY запросы конкретного студента
grep '"LAZY"' /home/student_pia_01/.logs/grading_log.json

# Основная таблица (через dashboard API)
curl http://<IP>:9000/api/results

# Счёт (через dashboard API)
curl http://<IP>:9000/api/stats
```

---

## Конфигурация

### .env переменные

| Переменная | Описание | По умолчанию |
|---|---|---|
| `JUPYTERHUB_PORT` | Порт JupyterHub | `8000` |
| `DASHBOARD_PORT` | Порт Dashboard | `9000` |
| `LLM_MENTOR_TYPE` | Тип LLM для ментора | `local` |
| `LLM_MENTOR_BASE_URL` | Endpoint LLM ментора | `http://llm:8080/v1` |
| `LLM_MENTOR_API_KEY` | API ключ для ментора | `local-api-key` |
| `LLM_MENTOR_MODEL` | Модель для ментора | `gpt-4o` |
| `LLM_CI_TYPE` | Тип LLM для CI/CD | `local` |
| `LLM_CI_BASE_URL` | Endpoint LLM CI/CD | `http://llm:8080/v1` |
| `LLM_CI_API_KEY` | API ключ для CI/CD | `local-api-key` |
| `LLM_CI_MODEL` | Модель для CI/CD | `gpt-4o` |
| `LLM_USE_LOCAL` | Использовать локальную LLM | `true` |
| `GITLAB_ROOT_PASSWORD` | Пароль GitLab root | auto-generated |
| `REGISTRY_PORT` | Порт Docker Registry | `5050` |
| `GITLAB_EXTERNAL_URL` | Внешний URL GitLab | `http://localhost` (или `http://<server-ip>`) |
| `GGUF_PATH` | Путь к GGUF (legacy-профиль LLM) | `/models/model.gguf` |
| `LECTURER_01_PASSWORD` | Пароль лектора 1 (GitLab-юзер `lecturer_1`) | auto-generated |
| `LECTURER_02_PASSWORD` | Пароль лектора 2 (GitLab-юзер `lecturer_2`) | auto-generated |
| `GITLAB_HOST` | IP/домен GitLab (SSH-доступ) | `localhost` (или `<server-ip>`) |
| `GITLAB_ADMIN_TOKEN` | Root-токен GitLab API | `glpat-placeholder` (авто-выставляется `init_gitlab.sh`) |

### docker-compose profile

Профили LLM взаимозаменяемы — используется только один.

```bash
# Без LLM (OpenAI API)
docker compose up -d

# С локальной LLM — GigaChat3.1 (рекомендуется для ментора)
docker compose --profile local-llm-gigachat up -d

# С локальной LLM — Qwen2.5-3B (легче, подходит для CI/CD)
docker compose --profile local-llm-qwen up -d

# legacy-профиль (требует GGUF модель в Docker volume)
docker compose --profile local-llm up -d

# Остановить все сервисы (включая LLM)
docker compose --profile local-llm-gigachat down -v

# Остановить только LLM
docker compose --profile local-llm-gigachat down llm-gigachat
# или
docker stop llm && docker rm llm
docker compose down
```

> **Важно:** Профили `local-llm-gigachat` и `local-llm-qwen` используют образы с встроенными моделями. Образы доступны в GHCR:
> ```bash
> # Вариант 1: setup.sh сам загрузит образы при запуске
> # Вариант 2: загрузить вручную
> docker pull ghcr.io/danil1online/istp-llm-gigachat:latest
> docker tag ghcr.io/danil1online/istp-llm-gigachat:latest istp-llm-gigachat:latest
> # или
> docker pull ghcr.io/danil1online/istp-llm-qwen:latest
> docker tag ghcr.io/danil1online/istp-llm-qwen:latest istp-llm-qwen:latest
> # Вариант 3: собрать локально (если нет доступа к GHCR)
> docker build -f llm/Dockerfile.gigachat -t istp-llm-gigachat:latest .
> docker build -f llm/Dockerfile.qwen -t istp-llm-qwen:latest .
> ```

---

## Устранение неполадок

### GitLab не стартует

```bash
# GitLab требует 2-3 минуты на первый запуск
docker logs gitlab

# Проверка базы данных
docker exec gitlab gitlab-rake db:status
```

### JupyterHub не входит

```bash
# Проверка логов
docker logs jupyterhub

# Проверка статуса контейнера
docker inspect --format='{{.State.Status}}' jupyterhub
```

### Runner не запускает jobs

```bash
# Проверка регистрации
docker exec gitlab-runner gitlab-runner verify

# Проверка SSH-ключа
ls -la shared/data/runner-keys/

# Проверка known_hosts
docker exec gitlab-runner cat ~/.ssh/known_hosts
```

### LLM не отвечает

```bash
# Проверка контейнера
docker logs llm

# Проверка модели
docker exec llm ls -la /models/

# Проверка API
curl http://llm:8080/v1/models
```

### LLM-образ не найден

```bash
# Проверка установленного образа
docker image inspect istp-llm-gigachat:latest
# или
docker image inspect istp-llm-qwen:latest

# Загрузка с GHCR (если есть доступ к интернету)
docker pull ghcr.io/danil1online/istp-llm-gigachat:latest
docker tag ghcr.io/danil1online/istp-llm-gigachat:latest istp-llm-gigachat:latest
# или
docker pull ghcr.io/danil1online/istp-llm-qwen:latest
docker tag ghcr.io/danil1online/istp-llm-qwen:latest istp-llm-qwen:latest

# Сборка образа (если нет доступа к GHCR)
docker build -f llm/Dockerfile.gigachat -t istp-llm-gigachat:latest .
# или
docker build -f llm/Dockerfile.qwen -t istp-llm-qwen:latest .

# Перезапуск с правильным профилем
docker compose --profile local-llm-gigachat up -d
# или
docker compose --profile local-llm-qwen up -d
```

### Dashboard не показывает логи

```bash
# Проверка логи студента (персональные файлы)
ls -la /home/{user}/.logs/grading_log.json

# Проверка агрегации через dashboard
docker exec admin-dashboard ls -la /home/*/.logs/grading_log.json

# Проверка формата
head -5 /home/{user}/.logs/grading_log.json
```

### Full restart

```bash
# Остановить всё (включая LLM в выбранном профиле)
docker compose --profile local-llm-gigachat down -v

# Очистить volumes (⚠️ удалит все данные!)
docker volume prune -f

# Перезапустить
sudo ./scripts/setup.sh
```

### Остановка LLM

```bash
# Для профиля GigaChat:
docker compose --profile local-llm-gigachat down llm-gigachat
# Для профиля Qwen:
docker compose --profile local-llm-qwen down llm-qwen
# Для legacy-профиля:
docker compose --profile local-llm down llm

# Ручная остановка (универсально)
docker stop llm && docker rm llm
```

### Health check

```bash
bash scripts/healthcheck.sh

# Ручная проверка каждого сервиса
docker compose ps
docker compose logs --tail=20
```

## ⚖️ Лицензирование используемых ИИ-моделей

Данный учебный комплекс осуществляет предзагрузку и локальное развёртывание сторонних предобученных моделей машинного обучения. Использование этих моделей регулируется их оригинальными лицензиями:

1. **BERT (`bert-base-uncased`)** — распространяется под свободной лицензией **Apache 2.0**. Разрешено неограниченное копирование и интеграция.
2. **Wav2Vec2 (`facebook/wav2vec2-large-960h-lv60-self`)** — разработка Meta, распространяется под свободной лицензией **Apache 2.0**.
3. **OpenAI Whisper (`base`)** — код и веса модели защищены максимально разрешающей лицензией **MIT**. Пользователи обязаны самостоятельно соблюдать авторские права на распознаваемые аудиоматериалы.
4. **ResNet34 и Mask R-CNN (`torchvision.models`)** — распространяются под лицензией **BSD 3-Clause**. Сами веса обучены на публичных датасетах ImageNet и COCO, что накладывает правила использования преимущественно в **некоммерческих, исследовательских и образовательных целях**.
5. **Датасет GLUE / STS-Benchmark (`glue/stsb`)** — распространяется по лицензии **Creative Commons Attribution 4.0 International (CC BY 4.0)**. При публикации научных работ на основе комплекса требуется указание авторства исследователей GLUE.

> 📌 **Примечание для вузов:** Пакетный состав и веса моделей подобраны исключительно для академического, учебного и научно-исследовательского использования в рамках лабораторных практикумов, что полностью соответствует условиям всех вышеперечисленных лицензий.
