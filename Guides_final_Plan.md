# Глобальный план доработки учебного комплекса ИСИСТ

> Создано: 2026-08-11
> Статус: В процессе

---

## Контекст

Обновление образовательного комплекса:
1. Добавить Docker socket в JupyterHub для Docker-in-Docker
2. Вернуть практику Docker + Telegram, но заменить Telegram на мессенджер MAX
3. Сдвинуть нумерацию практик на +1 (Pr_4 → Pr_5, ..., Pr_20 → Pr_21)
4. Исправить копирование изображений в GitLab-репозиторий students/project

---

## Шаг 1: Docker socket в JupyterHub

**Файл:** `docker-compose.yml`

**Изменение:** Добавить в volumes `jupyterhub`:
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

**Обоснование:** Docker-out-of-Docker (DooD) — контейнер JupyterHub получает доступ к Docker-демону хоста. Для учебной среды это оптимальный вариант (проще DinD).

---

## Шаг 2: Создать Pr_2.md (Docker + Telegram MAX)

**Исходник:** https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/blob/main/docs/Pr_2.md

**Что заменяется:**
| Было (Telegram) | Стало (MAX) |
|-----------------|-------------|
| `telepot==12.7` | `maxapi` |
| BotFather → регистрация | MasterBot → `/create` |
| `import telepot` | `from maxapi import Bot, Dispatcher, F` |
| `bot.message_loop(handle)` | `dp.start_polling(bot)` (asyncio) |
| Синхронный бот | Асинхронный бот |
| Приложение 2: BotFather | Приложение 2: MasterBot (MAX) |

**Структура:**
1. Теория: Docker (образы, контейнеры, Dockerfile, volumes, Registry)
2. Теория: MAX мессенджер, библиотека maxapi, long polling
3. Создание бота в MasterBot
4. Код эхо-бота на maxapi
5. Dockerfile для бота (multi-stage build)
6. Сборка, запуск, проверка
7. Сохранение образа в локальный Registry (:5050)
8. Приложение 1: VPS Docker (справочное)
9. Приложение 2: Регистрация бота MAX (MasterBot)
10. Приложение 3: Команды Docker

**Ссылки:**
- Статья: https://habr.com/ru/articles/930230/
- Библиотека: https://pypi.org/project/maxapi/
- GitHub: https://github.com/love-apples/maxapi
- Wiki: https://github.com/love-apples/maxapi/wiki

---

## Шаг 3: Сдвиг номеров практик

**Перенумерация файлов:**
| Исходный | Новый |
|----------|-------|
| `Pr_2.md` (Python структуры) | → `Pr_3.md` |
| `Pr_3.md` (Python функции) | → `Pr_4.md` |
| `Pr_4.md` (Matplotlib основы) | → `Pr_5.md` |
| `Pr_5.md` (Matplotlib диаграммы) | → `Pr_6.md` |
| `Pr_6.md` | → `Pr_7.md` |
| `Pr_7.md` | → `Pr_8.md` |
| `Pr_8.md` | → `Pr_9.md` |
| `Pr_9.md` | → `Pr_10.md` |
| `Pr_10.md` | → `Pr_11.md` |
| `Pr_11.md` | → `Pr_12.md` |
| `Pr_12.md` | → `Pr_13.md` |
| `Pr_13.md` | → `Pr_14.md` |
| `Pr_14.md` | → `Pr_15.md` |
| `Pr_15.md` | → `Pr_16.md` |
| `Pr_16.md` | → `Pr_17.md` |
| `Pr_17.md` | → `Pr_18.md` |
| `Pr_18.md` | → `Pr_19.md` |
| `Pr_19.md` | → `Pr_20.md` |
| `Pr_20.md` | → `Pr_21.md` |

**Что меняется внутри каждого файла:**
- Заголовок: `# Практическая работа №X` → `# Практическая работа №Y`
- Ссылки на другие практики: `Pr_N.md` → `Pr_M.md`
- Номера в текстах: "П.р. №4" → "П.р. №5"

---

## Шаг 4: Копирование images/ в students/project

**Файл:** `scripts/init_gitlab.sh`

**Проблема:** `cp "$DOCS_DIR"/*.md` копирует только .md, images не копируются.

**Решение:** Добавить после копирования docs:
```bash
cp -r "$DOCS_DIR/../images" "$TMP_DIR/" 2>/dev/null || true
```

---

## Шаг 5: Обновление путей изображений

**Проблема:** 20 ссылок вида `../images/...` предполагают images на уровень выше docs/

**Решение:** Заменить `../images/` → `images/` во всех файлах.

**Файлы для обновления:**
| Файл | Кол-во ссылок |
|------|--------------|
| `Pr_1.md` | 2 (GitHub URL → локальные) |
| `Pr_7.md` | 4 |
| `Pr_8.md` | 1 |
| `Pr_9.md` | 1 |
| `Pr_10.md` | 1 |
| `Pr_11.md` | 1 |
| `Pr_12.md` | 1 |
| `Pr_13.md` | 1 |
| `Pr_14.md` | 1 |
| `Pr_15.md` | 1 |
| `Pr_16.md` | 1 |
| `Pr_18.md` | 6 |
| `Pr_19.md` | 1 (локальная) |
| `Pr_20.md` | 1 |

**Пример:**
```markdown
# Было:
![Владка Notebook](../images/notebook_clear_window.png)

# Стало:
![Владка Notebook](images/notebook_clear_window.png)
```

---

## Шаг 6: Обновление README.md

**Изменения:**
1. Заголовки практических работ (номера сдвинулись)
2. Типы работ:
```markdown
# Было:
Terminal-based (Pr_0, Pr_1, Pr_2)
Notebook-based (Pr_3 — Pr_20)

# Стало:
Terminal-based (Pr_0, Pr_1)
Notebook-based (Pr_2 — Pr_21)
```

---

## Шаг 7: Обновление auto_grade.py

**Изменения:**
- `find_md_reports()` — исключить `Pr_1.md` + добавить `Pr_2.md`
- Комментарии: `Pr_2 — Pr_21` для notebook

---

## Шаг 8: Обновление PLAN_automated_grading.md

**Изменения:**
- Актуализировать нумерацию (Pr_21 вместо Pr_20)
- Обновить описание Pr_2 (Docker + MAX)

---

## Порядок выполнения

1. Docker-compose.yml — docker socket
2. Создать Pr_2.md (MAX)
3. Сдвиг номеров (самый объёмный)
4. init_gitlab.sh — копирование images
5. Пути изображений в docs/*.md
6. README.md
7. auto_grade.py
8. PLAN_automated_grading.md

---

## Примечания

- Все .md-файлы используют эмодзи-заголовки (🎯, 📌, 📁, 🧪, 📝)
- Формат отчётов: terminal-based (Pr_0, Pr_1) → .md; notebook-based (Pr_2+) → .ipynb
- LLM-ментор: `%%ask_mentor` — классифицирует LAZY/SMART запросы
- Автоматическая оценка: `.grade-trigger` → CI/CD → ai_report.json (0-5)
