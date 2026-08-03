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
┌──────────────────────────────────────────────────────────────┐
│                    HOST (Linux, 32+ GB RAM)                  │
│                                                              │
 │  Внешние порты:                                              │
│  GitLab:       80 (HTTP) / 2222 (SSH)                        │
│  JupyterHub:   8000 (по умолчанию)                           │
│  Nextcloud:    8080 (по умолчанию)                           │
│  Dashboard:    9000 (по умолчанию)                           │
│  Registry:     5050 (Docker Container Registry)              │
│                                                              │
│  Internal bridge network:                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐ │
│  │ Keycloak │  │ GitLab   │  │ Jupyter  │  │   Nextcloud  │ │
│  │ :9200    │  │ :80/22   │  │ :8000    │  │ :8080        │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────┬───────┘ │
│       │OIDC          │OIDC         │OIDC            │OIDC    │
│  ┌────┴──────────────┴─────────────┴───────────────┴───────┐ │
│  │              Keycloak (Identity Provider)                │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌┴──────────┐  ┌────────────┐  │
│  │ GitLab   │  │   LLM    │  │OnlyOffice │  │  Admin     │  │
│  │ Runner   │  │  (opt.)  │  │  (internal)│  │  Dashboard│  │
│  └──────────┘  └──────────┘  └───────────┘  └────────────┘  │
│  ┌──────────┐                                                │
│  │ Registry │  :5050 (Docker images для CI/CD)               │
│  └──────────┘                                                │
│                                                              │
│  Shared Volumes:                                             │
│    /shared/data        → материалы преподавателя             │
│    /shared/logs        → grading_log.json (JSON Lines)       │
│    /shared/student-work→ репозитории студентов               │
└──────────────────────────────────────────────────────────────┘
```

---

## Функционал

### Для студентов

| Функция | Описание |
|---|---|
| **Единый вход** | Регистрация в Keycloak → автоматический доступ ко всем сервисам |
| **ИИ-Ментор** | Команда `%%ask_mentor` в ячейках JupyterLab |
| **Классификация запросов** | LAZY (штраф) / SMART (поощрение) |
| **Онлайн-редактор** | OnlyOffice в браузере для создания отчётов |
| **Файловое хранилище** | Nextcloud с общим доступом к материалам курса |
| **SSH-ключи** | Генерация при первом входе, добавление в GitLab |
| **Git-репозиторий** | Личный репозиторий для каждого студента |
| **CI/CD проверка** | Автоматическая оценка ipynb-отчётов через LLM |

### Для преподавателя

| Функция | Описание |
|---|---|
| **Панель мониторинга** | Real-time дашборд с LAZY/SMART статистикой |
| **Фильтрация логов** | По студенту, дате, категории |
| **Экспорт данных** | CSV-экспорт за заданный период |
| **Диаграммы** | LAZY% по студентам, динамика по дням |
| **Авто-оценка** | CI/CD pipeline проверяет ноутбуки автоматически |
| **Группы студентов** | Организация по группам (pia, ista, istb, pa) |

---

## Структура проекта

```
├── docker-compose.yml           # Оркестрация 9 сервисов
├── .env.example                 # Шаблон переменных окружения
├── .env                         # Генерируется setup.sh (не коммитить)
│
├── scripts/
│   ├── setup.sh                 # Интерактивный инсталлятор
  │   ├── init_keycloak.sh         # Создание OIDC-клиентов
   │   ├── init_gitlab.sh           # Инициализация GitLab
   │   ├── init_nextcloud.sh        # Настройка Nextcloud + OnlyOffice
   │   └── healthcheck.sh           # Проверка здоровья сервисов
│
├── jupyterhub/
│   ├── Dockerfile               # JupyterHub + JupyterLab + oauthenticator
│   ├── jupyterhub_config.py     # OAuth, SimpleSpawner, hooks
│   ├── startup/
│   │   └── 00_mentor.py         # %%ask_mentor magic
│   ├── persona_mentor.py        # @mentor persona (MCP)
│   ├── jupyter_ai_config.json   # Конфигурация jupyter-ai
│   └── startup-hooks/
│       └── generate_ssh_keys.py # SSH-генерация при первом входе
│
├── llm/
│   ├── Dockerfile               # nvidia/cuda + llama.cpp
│   └── start-server.sh          # Запуск llama-server
│
├── runner/
│   ├── Dockerfile.python310     # Python 3.10 + nbconvert
│   ├── entrypoint.sh            # SSH + runner
│   └── scripts/
│       └── grade_notebook.py    # Оценка ноутбука через LLM
│
├── dashboard/
│   ├── Dockerfile               # Flask + Plotly
│   ├── app.py                   # Flask приложение
│   ├── routes.py                # REST API: logs, stats, export
│   ├── models.py                # Кэш логов
│   ├── templates/
│   │   └── dashboard.html       # Real-time дашборд
│   └── static/                  # CSS/JS (по желанию)
│
├── nextcloud/
│   └── config/
│       └── config.php           # OnlyOffice + OIDC настройки
│
├── docs/
│   ├── Pr_1.md                  # Инструкция по SSH и регистрации
│   └── ...                      # Остальные практические
│
├── shared/                      # Volumes mount point
│   ├── data/                    # Материалы преподавателя
│   ├── logs/                    # grading_log.json
│   └── student-work/            # Репозитории студентов
│
└── README_new.md                # Этот файл
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

#### Keycloak
```
Image: quay.io/keycloak/keycloak:26.1
RAM: ~700 MB
```

#### GitLab CE
```
Image: gitlab/gitlab-ce:latest
RAM: ~4 GB
Ports: 80, 2222
```

#### GitLab Runner
```
Image: gitlab/gitlab-runner:latest
RAM: ~100 MB
Mount: /var/run/docker.sock
```

#### JupyterHub
```
Base: python:3.10-slim
Packages: jupyterhub, jupyterlab, GenericOAuthenticator, jupyter-ai
RAM: ~500 MB на спавн
```

#### Nextcloud
```
Image: nextcloud:apache
RAM: ~300 MB
```

#### OnlyOffice Document Server
```
Image: onlyoffice/documentserver:latest
RAM: ~1 GB
```

#### LLM (опционально)
```
Base: ghcr.io/ggml-org/llama.cpp:server-cuda12
Build: Dockerfile → start-server.sh, initialize.sh
RAM: ~2 GB + VRAM (зависит от модели)
```

#### Admin Dashboard
```
Base: python:3.10-slim
Packages: flask, plotly, requests
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
1. Порт JupyterHub (по умолчанию: `8000`)
2. Порт Admin Dashboard (по умолчанию: `9000`)
3. Порт Nextcloud (по умолчанию: `8080`)
4. Адрес GitLab (http://<IP_или_домен>)
5. LLM для ментора: OpenAI API / локальный контейнер
6. LLM для CI/CD: OpenAI API / локальный контейнер
7. Путь к `.gguf` модели (если локальный режим)
8. SSH-ключ для GitLab Runner

### 4. Доступы

После установки скрипт выведет:

```
Keycloak (регистрация): http://<IP>:9200/auth/realms/istp/account/

GitLab:       http://<IP>:80
  Root:       root / <generated password>
  Lecturer:   lecturer_01 / <generated password> (смените!)
  Lecturer:   lecturer_02 / <generated password> (смените!)

JupyterHub:   http://<IP>:8000
  Вход:       через Keycloak (кнопка на странице входа)

Nextcloud:    http://<IP>:8080
  Admin:      admin / <generated password>

Dashboard:    http://<IP>:9000
  Admin:      lecturer_01 (через Keycloak OIDC)
```

### 5. Административные доступы

| Сервис | Логин | Пароль | URL |
|---|---|---|---|
| **GitLab (root)** | `root` | см. `.env` → `GITLAB_ROOT_PASSWORD` | `http://<IP>:80` |
| **Keycloak (admin)** | `admin` | см. `.env` → `KC_ADMIN_PASSWORD` | `http://<IP>:9200/auth` |
| **Nextcloud (admin)** | `admin` | см. `.env` → `NC_ADMIN_PASSWORD` | `http://<IP>:8080` |
| **JupyterHub** | любой (через Keycloak) | тот же, что в Keycloak | `http://<IP>:<JUPYTERHUB_PORT>` |
| **Dashboard** | lecturer_01 (через Keycloak OIDC) | см. `.env` → `LECTURER_01_PASSWORD` | `http://<IP>:<DASHBOARD_PORT>` |

> **Важно:** Все пароли генерируются при запуске `setup.sh` и хранятся в файле `.env`.
> Для просмотра паролей после установки: `cat .env | grep -E "GITLAB_ROOT_PASSWORD|KC_ADMIN_PASSWORD|NC_ADMIN_PASSWORD|LECTURER_"`
>
> **Пароль Keycloak admin по умолчанию:** `Keycloak123!` (если не переопределён в `.env`)
>
> **⚠️ Лекторы:** пароли lecturer_01/lecturer_02 нужно сменить после первого входа!

### 6. Добавление SSH-ключа для GitLab Runner

```bash
# Скопируйте публичный ключ
cat shared/data/runner-keys/runner_ed25519.pub

# Добавьте в GitLab:
# Settings → Repository → Deploy Keys → Add key
```

---

## Инсталляция

### Интерактивный setup.sh

Скрипт `scripts/setup.sh` выполняет последовательно:

```
ШАГ 1/8: Настройка портов
  → JupyterHub (по умолчанию 8000)
  → Dashboard (по умолчанию 9000)
  → Nextcloud (по умолчанию 8080)

ШАГ 2/8: Адрес GitLab
  → http://<IP_или_домен>

ШАГ 3/8: LLM для ИИ-Ментора
  → Выбор: OpenAI API / Локальный контейнер
  → Если OpenAI: endpoint IP:port + API ключ
  → Если локальный: путь к .gguf (2 попытки, иначе выход)

ШАГ 4/8: LLM для CI/CD
  → Выбор: OpenAI API / Локальный
  → Если обе локальные: предупреждение, одна модель
  → Если OpenAI + локальная: второй путь к .gguf

ШАГ 5/8: Генерация паролей
   → Keycloak admin, GitLab root, Nextcloud admin, OnlyOffice JWT

ШАГ 6/8: SSH-ключ для GitLab Runner
  → Генерация ED25519 ключа
  → Сохранение в shared/data/runner-keys/

ШАГ 7/8: Генерация .env
  → Запись всех конфигураций в .env файл

ШАГ 8/8: Запуск сервисов
   → docker compose up -d
   → Healthcheck Keycloak, GitLab, Nextcloud
   → Инициализация Keycloak (OIDC-клиенты)
   → Инициализация GitLab (группа, админ)
   → Инициализация Nextcloud (OnlyOffice)
   → Регистрация GitLab Runner
```

### Ручная установка

```bash
# 1. Скопируйте шаблон
cp .env.example .env

# 2. Отредактируйте .env
nano .env

# 3. Поднимите сервисы
docker compose up -d keycloak gitlab nextcloud onlyoffice admin-dashboard
# Для локальной LLM:
docker compose up -d llm

# 4. Дождитесь готовности
sleep 300
docker compose up -d jupyterhub

# 5. Инициализация
bash scripts/init_keycloak.sh
bash scripts/init_gitlab.sh
bash scripts/init_nextcloud.sh

# 6. Регистрация Runner
docker exec -it gitlab-runner gitlab-runner register \
  --url http://gitlab:80 \
  --token <registration-token> \
  --executor docker \
  --docker-image python:3.10 \
  --tag-list docker_runner
```

---

## Архитектура сервисов

### 1. Keycloak (OIDC Provider)

```yaml
Image: quay.io/keycloak/keycloak:26.1
Port: 9200 (internal)
Volume: keycloak-data
```

**Роль:** Единый провайдер аутентификации (OIDC) для всех сервисов.

**OIDC-клиенты:**
| Клиент | Redirect URI |
|---|---|
| JupyterHub | `http://<IP>:8000/hub/oauth_callback` |
| Admin Dashboard | `http://<IP>:9000/callback` |
| Nextcloud | `http://<IP>:8080/apps/oidc_login/callback` |
| GitLab | `http://<IP>/oauth/callback` |

**Авторизация:** Keycloak OIDC → GitLab, JupyterHub, Nextcloud, Dashboard

### 2. GitLab CE

```yaml
Image: gitlab/gitlab-ce:latest
Ports: 80 (HTTP), 2222 (SSH)
Volumes: gitlab-config, gitlab-logs, gitlab-data
```

**Роль:** SCM, CI/CD, файловое хранилище отчётов.

**Авторизация:** Keycloak OIDC (через кнопку "Keycloak" на странице входа).

**Группы:** `students` — для всех студенческих проектов.

**SSH-порты:** `git@gitlab:2222` для SSH-доступа.

### 3. JupyterHub

```yaml
Build: ./jupyterhub
Port: 8000 (по умолчанию)
Auth: Keycloak OIDC (GenericOAuthenticator)
Spawner: SimpleSpawner
```

**Ключевые компоненты:**
- **GenericOAuthenticator** — авторизация через Keycloak OIDC
- **create_missing_users = True** — авто-создание учётки при первом OAuth-входе
- **SimpleSpawner** — простой спавнер JupyterLab
- **pre_spawn_start hook** — копирование шаблонов `.ipynb` при первом входе
- **SSH-генерация** — Ed25519 ключ при первом входе

### 4. Nextcloud + OnlyOffice

```yaml
Nextcloud:  nextcloud:apache
OnlyOffice: onlyoffice/documentserver:latest
Port: 8080 (Nextcloud)
```

**Роль:** Файловое хранилище + онлайн-редактор документов.

**OnlyOffice интеграция:**
- Создание DOCX в браузере
- Экспорт в PDF
- Коллаборативное редактирование

**OIDC авторизация:** через Keycloak

### 5. LLM (опционально)

```yaml
Build: ./llm (ghcr.io/ggml-org/llama.cpp:server-cuda12)
Port: 8080 (internal only)
Model: Qwen3.5-0.8B-Q4_K_M.gguf
Args: -ngl 99 -c 65536
```

**Роль:** Локальный инференс LLM через OpenAI-совместимый API.

**API Endpoints:**
```
POST /v1/chat/completions
POST /v1/embeddings
GET  /v1/models
```

### 6. GitLab Runner

```yaml
Image: gitlab/gitlab-runner:latest
Docker: python:3.10
Tags: docker_runner, python3.10
```

**Роль:** CI/CD runner для проверки ноутбуков.

**Пайплайн:**
```yaml
stages:
  - review

ai_review:
  stage: review
  tags: [docker_runner]
  script:
    - jupyter execute notebook.ipynb
    - python grade_notebook.py notebook.ipynb
  artifacts:
    paths:
      - ai_report.json
    expire_in: 1 week
```

### 7. Admin Dashboard

```yaml
Build: ./dashboard (Flask)
Port: 9000
Refresh: auto 5 seconds
```

**API Endpoints:**
| Эндпоинт | Описание |
|---|---|
| `GET /` | HTML дашборд |
| `GET /api/logs` | Логи с фильтрацией |
| `GET /api/stats` | LAZY/SMART ratio по студентам |
| `GET /api/summary` | Общая сводка |
| `GET /api/export` | CSV экспорт |

**Фильтры:**
- По студенту (`?student=student_pia_01`)
- По дате (`?date_from=2025-09-01&date_to=2025-12-31`)
- По категории (`?category=LAZY|SMART`)

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
                        ├→ /shared/logs/grading_log.json
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

### Схема OAuth / OIDC

```
Keycloak (Identity Provider)
    │
    │ self-registration + OIDC
    │
    ┌───────┼──────────┬──────────────┐
    │       │          │              │
    ▼       ▼          ▼              ▼
GitLab  JupyterHub  Nextcloud   Admin Dashboard
(OIDC)  (OIDC)      (OIDC)      (OIDC)
```

### Auto-provisioning

1. Студент регистрируется в Keycloak (через GitLab → Keycloak → Register)
2. С теми же данными входит в JupyterHub, Nextcloud, GitLab
3. `GenericOAuthenticator` создаёт учётку автоматически (`create_missing_users = True`)
4. **pre_spawn_hook** копирует шаблоны `.ipynb`, генерирует SSH-ключ
5. GitLab создаёт пользователя при первом OIDC-входе

### Fallback

**Нет fallback** — при недоступности Keycloak/JupyterHub студенты не смогут войти. Рекомендуется:
- Дублирование Keycloak-бэкапов
- Мониторинг через healthcheck

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
  - review

ai_review:
  stage: review
  tags: [docker_runner]
  script:
    - pip install jupyter nbconvert
    - jupyter execute notebook.ipynb
    - python grade_notebook.py notebook.ipynb
  artifacts:
    paths:
      - ai_report.json
    expire_in: 1 week
  only:
    - main
```

### Оценка ноутбука

`grade_notebook.py` проверяет:
1. **executes** — выполняется ли код без ошибок
2. **has_explanation** — есть ли поясняющие ячейки
3. **score** — оценка 0-100
4. **grade** — A/B/C/D/F
5. **feedback** — детальный отзыв
6. **issues** — список проблем
7. **recommendations** — рекомендации

### Шаблон проекта

При создании группы `students` автоматически создаётся шаблонный проект `academic-template`, который студенты форкают.

### Docker Container Registry

Система включает локальный Docker Registry на порту `5050` для хранения образов, используемых в CI/CD.

```bash
# Авторизация в registry
docker login http://<gitlab-ip>:5050

# Push образа (пример из CI/CD пайплайна)
docker tag my-app <gitlab-ip>:5050/students/my-app:latest
docker push <gitlab-ip>:5050/students/my-app:latest

# Pull образа (runner использует для запуска задач)
docker pull <gitlab-ip>:5050/students/my-app:latest
```

Registry доступен по адресу `http://<gitlab-ip>:5050` (порт настраивается через `REGISTRY_PORT` в `.env`).

---

## Admin Dashboard

### Интерфейс

```
╔══════════════════════════════════════════╗
║  🎓 Панель преподавателя — Monitoring    ║
╠══════════════════════════════════════════╣
║  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐    ║
║  │All │ │LAZY│ │SMART││Pen ││Std │    ║
║  │142 │ │ 43 │ │  99 │ │ 28 │ │ 29 │    ║
║  └────┘ └────┘ └────┘ └────┘ └────┘    ║
╠══════════════════════════════════════════╣
║  Фильтры: [Студент ▼] [Катег ▼] [С-По] ║
╠══════════════════════════════════════════╣
║  Время  │ Студент  │ LAZY│ ⚠ │ Запрос  ║
║  14:30  │ pia_01   │SMART│ — │ "Как..."║
║  14:35  │ pia_02   │ LAZY│ ⚠ │ "Напиши"║
║  ...
╚══════════════════════════════════════════╝
```

### Real-time обновление

- Auto-refresh каждые 5 секунд через `setInterval`
- SSE (Server-Sent Events) для push-уведомлений (в будущем)

### API эндпоинты

```bash
# Все логи с фильтрацией
curl http://<IP>:9000/api/logs?student=student_pia_01&category=LAZY

# Статистика по студентам
curl http://<IP>:9000/api/stats

# Общая сводка
curl http://<IP>:9000/api/summary

# CSV экспорт
curl -O http://<IP>:9000/api/export?date_from=2025-09-01
```

---

## Использование студентом

### Пошаговый алгоритм

```
Шаг 1. Регистрация
  └→ Открыть GitLab → Sign in → Keycloak → Register → student_<группа>_<номер>

Шаг 2. SSH-ключ
  └→ JupyterLab Terminal → ssh-keygen
  └→ GitLab Settings → SSH Keys → добавить ключ

Шаг 3. Практическая 1 (Git)
  └→ Терминал JupyterLab + GitLab UI
  └→ Отчёт: PDF → репозиторий Reports (вручную)

Шаг 4. Практическая 2+ (ipynb)
  ├── ИИ-Ментор: %%ask_mentor в ячейках
  ├── Отчёт: ipynb → скачать → PDF → репозиторий Reports (вручную)
  └── CI/CD: Runner проверяет ipynb автоматически
```

### Пример работы с ИИ-Ментором

```python
# SMART запрос (поощрение)
%%ask_mentor
Я написал функцию, но возникает ошибка KeyError.
Вот мой код:
df = pd.read_csv('data.csv')
print(df['nonexistent_column'])
# Почему возникает KeyError?

# Результат:
# 🤖 Ментор: Отлично, что вы приложили код! KeyError означает,
# что столбец 'nonexistent_column' не существует в датафрейме.
# Попробуйте print(df.columns) чтобы увидеть доступные столбцы.
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
3. Фильтровать по студенту, дате, категории
4. Экспортировать CSV для отчётов

### Проверка CI/CD

1. Открыть проект студента в GitLab
2. Перейти в **CI/CD → Pipelines**
3. Посмотреть результат `ai_review`
4. Скачать артефакт `ai_report.json`

### Просмотр логов

```bash
# Все запросы студента
tail -f shared/logs/grading_log.json | grep student_pia_01

# LAZY запросы
grep '"LAZY"' shared/logs/grading_log.json

# Счёт
grep -c '"LAZY"' shared/logs/grading_log.json
grep -c '"SMART"' shared/logs/grading_log.json
```

---

## Конфигурация

### .env переменные

| Переменная | Описание | По умолчанию |
|---|---|---|
| `JUPYTERHUB_PORT` | Порт JupyterHub | `8000` |
| `DASHBOARD_PORT` | Порт Dashboard | `9000` |
| `NEXTCLOUD_PORT` | Порт Nextcloud | `8080` |
| `KEYCLOAK_PORT` | Порт Keycloak | `9200` |
| `LLM_MENTOR_TYPE` | Тип LLM для ментора | `local` |
| `LLM_MENTOR_BASE_URL` | Endpoint LLM ментора | `http://llm:8080/v1` |
| `LLM_CI_TYPE` | Тип LLM для CI/CD | `local` |
| `LLM_CI_BASE_URL` | Endpoint LLM CI/CD | `http://llm:8080/v1` |
| `GGUF_PATH` | Путь к модели | `/models/Qwen3.5-0.8B-Q4_K_M.gguf` |
| `LLM_USE_LOCAL` | Использовать локальную LLM | `true` |
| `KC_ADMIN_PASSWORD` | Пароль Keycloak admin | `Keycloak123!` |
| `GITLAB_ROOT_PASSWORD` | Пароль GitLab root | auto-generated |
| `REGISTRY_PORT` | Порт Docker Registry | `5050` |
| `NC_ADMIN_PASSWORD` | Пароль Nextcloud admin | auto-generated |
| `ONLYOFFICE_JWT_SECRET` | JWT для OnlyOffice | auto-generated |
| `JH_API_TOKEN` | JupyterHub API token | auto-generated |
| `GITLAB_HOST` | IP/домен GitLab | `10.8.1.3` (или другой) |
| `HOST_DOMAIN` | Домен хоста | `10.8.1.3` |

### docker-compose profile

```bash
# Без LLM (OpenAI API)
docker compose up -d

# С локальной LLM
docker compose --profile local-llm up -d
```

---

## Устранение неполадок

### GitLab не стартует

```bash
# GitLab требует 2-3 минуты на первый запуск
docker logs gitlab

# Проверка базы данных
docker exec gitlab gitlab-rake db:status
```

### Keycloak не отвечает

```bash
# Keycloak должен быть health перед другими сервисами
docker inspect --format='{{.State.Health.Status}}' keycloak

# Проверка логов
docker logs keycloak
```

### JupyterHub не входит

```bash
# Проверка OAuth-конфигурации
docker logs jupyterhub | grep -i oauth
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

### Dashboard не показывает логи

```bash
# Проверка volume
docker exec admin-dashboard ls -la /app/logs/

# Проверка прав
ls -la shared/logs/

# Проверка формата
head -5 shared/logs/grading_log.json
```

### Full restart

```bash
# Остановить всё
docker compose down -v

# Очистить volumes (⚠️ удалит все данные!)
docker volume prune -f

# Перезапустить
sudo ./scripts/setup.sh
```

### Health check

```bash
bash scripts/healthcheck.sh

# Ручная проверка каждого сервиса
docker compose ps
docker compose logs --tail=20
```
