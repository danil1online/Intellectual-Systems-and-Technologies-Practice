# Практическая 1: Предварительная настройка учебного комплекса

## Цель работы
Настроить рабочее окружение: регистрация в GitLab, настройка SSH-ключей, первый вход в JupyterHub и Nextcloud.

---

## 1. Регистрация в GitLab

1. Откройте в браузере **GitLab**: `http://<server-ip>:80`
2. Нажмите **Sign in** → **Sign up**
3. Заполните форму:
   - **Username**: `student_<группа>_<номер>` (например: `student_pia_01`)
   - **Email**: ваш студенческий email
   - **Password**: придумайте надёжный пароль (запомните его!)
4. Нажмите **Sign up**

> ✅ Ваша учётная запись автоматически создана в JupyterHub и Nextcloud.

---

## 2. Генерация SSH-ключа

Студентам необходимо сгенерировать SSH-ключ для работы с GitLab из терминала JupyterLab.

### Шаг 1: Откройте Terminal в JupyterLab

1. Откройте **JupyterHub**: `http://<server-ip>:<port>`
2. Войдите через **GitLab OAuth** (кнопка "Sign in with GitLab")
3. В главном меню JupyterLab нажмите **File → New → Terminal**

### Шаг 2: Сгенерируйте SSH-ключ

```bash
ssh-keygen -t ed25519 -C "student_<группа>_<номер>@academic"
```

Нажмите Enter на все вопросы (без passphrase).

### Шаг 3: Посмотрите публичный ключ

```bash
cat ~/.ssh/id_ed25519.pub
```

Вы увидите строку вида:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... student_pia_01@academic
```

**Скопируйте эту строку!**

### Шаг 4: Добавьте ключ в GitLab

1. Откройте GitLab: `http://<server-ip>:80`
2. Войдите под своим логином
3. Перейдите: **Settings (меню слева) → SSH Keys**
4. Вставьте скопированный ключ в поле **Key**
5. Нажмите **Add key**

> 🔑 Ключ добавлен! Теперь вы можете работать с Git по SSH.

---

## 3. Доступы к сервисам

| Сервис | URL | Логин | Пароль |
|---|---|---|---|
| **GitLab** | `http://<server-ip>:80` | student_XXX_NNN | Ваш при регистрации |
| **JupyterHub** | `http://<server-ip>:<port>` | через GitLab OAuth | тот же |
| **Nextcloud** | `http://<server-ip>:8080` | через GitLab OAuth | тот же |
| **Dashboard** | `http://<server-ip>:9000` | только преподаватель | — |

---

## 4. Работа с Git в JupyterLab

После настройки SSH-ключа вы можете работать с Git прямо из терминала JupyterLab:

```bash
# Клонирование репозитория
git clone git@gitlab.local:students/academic-template.git

# Или HTTPS (с personal access token)
git clone https://gitlab.local/students/academic-template.git
```

### Создание Personal Access Token для HTTPS

1. GitLab → **Settings → Access Tokens**
2. Выберите scopes: `read_repository`, `write_repository`
3. Нажмите **Create token**
4. Скопируйте token — он понадобится для HTTPS клонирования

---

## 5. Nextcloud + OnlyOffice

1. Откройте **Nextcloud**: `http://<server-ip>:8080`
2. Войдите через GitLab OAuth
3. В меню приложений включите **OnlyOffice** (если не включён автоматически)
4. Создайте документ DOCX прямо в браузере через OnlyOffice
5. Экспортируйте в PDF: **File → Export → PDF**

---

## 6. Использование ИИ-Ментора

В JupyterLab для общения с ИИ используйте магическую команду `%%ask_mentor`:

```python
%%ask_mentor
Я пытаюсь написать функцию сортировки, вот мой код:
def my_sort(arr):
    for i in range(len(arr)+1):
        min_idx = i
        ...
Почему возникает IndexError?
```

ИИ-ментор классифицирует ваш запрос:
- **SMART** — вы прикладываете код и спрашиваете про ошибку ✅
- **LAZY** — просите решить за вас ⚠️ (штраф)

Все запросы логируются и доступны преподавателю.

---

## Отчёт по работе

1. Сделайте скриншот:
   - Ваша учётная запись в GitLab (Settings → Account)
   - Ваш SSH-ключ в GitLab (Settings → SSH Keys)
   - Терминал JupyterLab с результатом `cat ~/.ssh/id_ed25519.pub`
2. Сохраните отчёт как `Pr_1_<группа>_<номер>.ipynb`
3. Выполните все ячейки
4. Скачайте как PDF
5. Загрузите PDF в репозиторий **Reports** в GitLab

---

## Критерии оценки

| Критерий | Баллы |
|---|---|
| Учётная запись в GitLab создана | 2 |
| SSH-ключ сгенерирован и добавлен | 3 |
| Скриншоты выполнены корректно | 2 |
| Ноутбук выполнен и запущен | 2 |
| **Итого** | **10** |
