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
│   ├── Dockerfile               # ghcr.io/ggml-org/llama.cpp:server-cuda12
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

├── docs/
│   ├── Pr_1.md                  # Инструкция по SSH и регистрации
│   └── ...                      # Остальные практические
│
├── shared/                      # Volumes mount point
│   ├── data/                    # Материалы преподавателя
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
Packages: jupyterhub, jupyterlab, nativeauthenticator, jupyter-ai
RAM: ~500 MB на спавн
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
1. Внешний адрес сервера (IP или домен)
2. Порт JupyterHub (по умолчанию: `8000`)
3. Порт Admin Dashboard (по умолчанию: `9000`)
4. LLM для ментора: OpenAI API / локальный контейнер (+ имя модели)
5. LLM для CI/CD: OpenAI API / локальный контейнер (+ имя модели)
6. Путь к `.gguf` модели (если локальный режим, будет переименована в model.gguf)
7. SSH-ключ для GitLab Runner

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
  → Если локальный: путь к .gguf (2 попытки, иначе выход)
  → Модель будет переименована в model.gguf перед записью в volume

ШАГ 4/11: LLM для CI/CD
  → Выбор: OpenAI API / Локальный
  → Если обе локальные: предупреждение, одна модель
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
  → Загрузка всех образов (GPU-образ может занять 5-10 минут)

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
# Для локальной LLM:
docker compose --profile local-llm up -d llm

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
  --docker-image python:3.10 \
  --tag-list istp-runner
```

---

## Архитектура сервисов

### 1. GitLab CE

```yaml
Image: gitlab/gitlab-ce:latest
Ports: 80 (HTTP), 2222 (SSH)
Volumes: gitlab-config, gitlab-logs, gitlab-data
```

**Роль:** SCM, CI/CD, файловое хранилище отчётов.

**Авторизация:** Встроенная саморегистрация (форма Sign up на странице входа).

**Группы:** `students` — для всех студенческих проектов.

**SSH-порты:** `git@gitlab:2222` для SSH-доступа.

### 2. JupyterHub

```yaml
Build: ./jupyterhub
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

### 4. LLM (опционально)

```yaml
Build: ./llm (ghcr.io/ggml-org/llama.cpp:server-cuda12)
Port: 8080 (internal only)
Model: model.gguf (универсальное имя, переименовывается из оригинала)
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
  - grade

grade:
  stage: grade
  tags:
    - istp-runner
  before_script:
    - pip install --no-cache-dir nbformat nbconvert requests python-dotenv
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

**Запуск оценки:** CI запускается на каждый push в `main`. Оценка срабатывает только при наличии файла `.grade-trigger` в репозитории — студенты создают его вручную в финальном действии каждой работы. Это предотвращает ложные оценки на промежуточных push.

### 7. Docker Registry

```yaml
Image: registry:2
Port: 5050 (external)
```

**Роль:** Standalone Docker Registry для хранения образов. Отдельный сервис, не встроенный в GitLab.

### 8. Admin Dashboard

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
| `GET /api/grades` | Оценки студентов (0-5) |
| `POST /api/grade` | Runner отправляет оценку |
| `GET /api/gitlab/groups` | Группы GitLab |
| `GET /api/gitlab/projects` | Проекты GitLab |
| `GET /api/gitlab/stats` | Сводка GitLab |

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
- Сбор данных для Dashboard: логи и оценки пишутся в `/home/{username}/`, откуда Dashboard их читает

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
  before_script:
    - pip install --no-cache-dir nbformat nbconvert requests python-dotenv
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

`auto_grade.py` — автоматический запуск при push в `main`:
1. Проверяет наличие `.grade-trigger` (создаётся студентом в финальном действии)
2. Определяет тип: `.ipynb` или `.md`
3. Запускает appropriate grader
4. Сохраняет `ai_report.json`
5. Очищает временные файлы

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
╔════════════════════════════════════════════╗
║  🎓 Панель преподавателя — Monitoring      ║
╠════════════════════════════════════════════╣
║  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐       ║
║  │ All  │ │ LAZY │ │SMART │ │Penal │       ║
║  │ 142  │ │  43  │ │  99  │ │  28  │       ║
║  └──────┘ └──────┘ └──────┘ └──────┘       ║
╠════════════════════════════════════════════╣
║  Фильтры: [Студент ▼] [Практика ▼]         ║
╠════════════════════════════════════════════╣
║  📊 Оценки студентов                      ║
║  Студент  │ Практика │ Оценка │ Feedback   ║
║  pia_01   │ Pr_7     │  4/5   │ ...        ║
║  pia_02   │ Pr_1     │  3/5   │ ...        ║
╠════════════════════════════════════════════╣
║  📝 Логи ИИ-Ментора                        ║
║  Время  │ Студент  │ LAZY │ ⚠ │ Запрос     ║
║  14:30  │ pia_01   │SMART │ — │ "Как..."   ║
║  14:35  │ pia_02   │ LAZY │ ⚠ │ "Напиши"   ║
║  ...                                       ║
╚════════════════════════════════════════════╝
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

Шаг 6. Практическая 3+ (ipynb)
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
3. Фильтровать по студенту, дате, категории
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
| `LLM_CI_TYPE` | Тип LLM для CI/CD | `local` |
| `LLM_CI_BASE_URL` | Endpoint LLM CI/CD | `http://llm:8080/v1` |
| `GGUF_PATH` | Путь к модели | `/models/model.gguf` |
| `LLM_USE_LOCAL` | Использовать локальную LLM | `true` |
| `GITLAB_ROOT_PASSWORD` | Пароль GitLab root | auto-generated |
| `REGISTRY_PORT` | Порт Docker Registry | `5050` |
| `JH_API_TOKEN` | JupyterHub API token | auto-generated |
| `GITLAB_HOST` | IP/домен GitLab | `10.8.1.3` (или другой) |
| `GITLAB_URL` | URL GitLab для Dashboard API | `http://gitlab:80` |
| `GITLAB_ADMIN_TOKEN` | PAT для доступа к GitLab API | `glpat-placeholder` |

### docker-compose profile

```bash
# Без LLM (OpenAI API)
docker compose up -d

# С локальной LLM
docker compose --profile local-llm up -d

# Остановить все сервисы (включая LLM)
docker compose --profile local-llm down -v

# Остановить только LLM
docker compose --profile local-llm down llm

# Ручная очистка (если docker compose down не остановил llm)
docker stop llm && docker rm llm
docker compose down
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
# Остановить всё (включая LLM в профиле local-llm)
docker compose --profile local-llm down -v

# Очистить volumes (⚠️ удалит все данные!)
docker volume prune -f

# Перезапустить
sudo ./scripts/setup.sh
```

### Остановка LLM

```bash
# LLM находится в профиле local-llm, обычный down не стопит его
docker compose --profile local-llm down llm

# Ручная остановка
docker stop llm && docker rm llm
```

### Health check

```bash
bash scripts/healthcheck.sh

# Ручная проверка каждого сервиса
docker compose ps
docker compose logs --tail=20
```
