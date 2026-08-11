# Практическая работа №2: Основы контейнеризации и чат-боты для мессенджера MAX

---

## 🎯 Цель работы

Изучение основ контейнеризации с Docker и создание чат-бота для мессенджера MAX с развёртыванием в Docker-контейнере.

---

## 📁 Материалы и методы

- Операционная система — [Ubuntu 22.04](https://help.ubuntu.ru/wiki/командная_строка)
- Язык программирования — [Python](https://www.python.org/)
- Основные технологии:
  - [Docker](https://www.docker.com/)
  - [maxapi](https://pypi.org/project/maxapi/) — библиотека для создания ботов MAX
  - [Git](https://habr.com/ru/articles/541258/)

---

## 🧪 Программа работы

---

### ⚙️ Настройка среды

**Авторизуйтесь на сервере JupyterHub**: `http://<server-ip>:8000`, войдите под своей учётной записью.

![Авторизация](images/autorization.png)

**Создайте новую вкладку Terminal**

![Создание вкладки Terminal](images/terminal_window_create.png)

**Работайте в новой вкладке вида**

![Вкладка Terminal](images/basic_window.png)

---

### 📌 Часть 1. Создание бота для мессенджера MAX

#### Шаг 1: Подготовка окружения

Создайте каталог для работы:
```bash
mkdir pr_2
cd pr_2
```

Проверьте работу Python 3.10:
```bash
python3.10
```
Выход:
```python
exit()
```

Создайте и активируйте виртуальное окружение:
```bash
python3.10 -m venv env
source env/bin/activate
```

В начале командной строки появится `(env)`:
```
(env) student@uuser-X10X99-16D:~/pr_2$
```

#### Шаг 2: Установка библиотеки maxapi

```bash
pip install maxapi
```

#### Шаг 3: Создание бота в MasterBot

1. Откройте мессенджер MAX и найдите пользователя **MasterBot**
2. Отправьте команду `/create`
3. Отправьте ник для бота (например: `my_pr2_bot`)
4. Отправьте имя для бота (например: `Мой практический бот`)
5. Скопируйте токен — он понадобится для кода

> 📌 Токен имеет вид строки, аналогичной Telegram-токену: `123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ`

#### Шаг 4: Код бота

Создайте файл `bot.py`:
```bash
nano bot.py
```

Содержимое — эхо-бот на `maxapi` с асинхронной обработкой:
```python
import asyncio
import logging

from maxapi import Bot, Dispatcher, F
from maxapi.types import MessageCreated

logging.basicConfig(level=logging.INFO)

# Замените 'ВАШ_ТОКЕН' на токен из MasterBot
bot = Bot('ВАШ_ТОКЕН')
dp = Dispatcher()


@dp.message_created(F.message.body.text)
async def echo(event: MessageCreated):
    await event.message.answer(f"Повторяю: {event.message.body.text}")


async def main():
    await dp.start_polling(bot)


if __name__ == '__main__':
    asyncio.run(main())
```

Сохраните файл `Ctrl+O`, выйдите `Ctrl+X`.

Замените `'ВАШ_ТОКЕН'` на ваш реальный токен.

#### Шаг 5: Запуск бота

```bash
python bot.py
```

Отправьте боту любое сообщение в MAX — он должен повторить его.

> 💡 Для остановки нажмите `Ctrl+C`

---

### 📌 Часть 2. Развёртывание бота в Docker-контейнере

#### Шаг 6: Создание requirements.txt

```bash
nano requirements.txt
```

Содержимое:
```
maxapi
```

Сохраните файл.

#### Шаг 7: Создание Dockerfile

```bash
nano Dockerfile
```

Содержимое — multi-stage build:
```dockerfile
FROM python:3.10 AS builder

COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.10-slim
WORKDIR /code
COPY --from=builder /root/.local /root/.local
COPY ./bot.py .
ENV PATH=/root/.local:$PATH
CMD ["python", "-u", "./bot.py"]
```

> 💡 Multi-stage build уменьшает размер итогового образа: первый этап (`builder`) устанавливает зависимости, второй — минимальный образ только с кодом.

Сохраните файл.

#### Шаг 8: Сборка Docker-образа

Соберите образ с именем — номером вашей зачётки:
```bash
docker build -t 000000 .
```

> ⚠️ Замените `000000` на ваш номер зачётки.

#### Шаг 9: Запуск контейнера

```bash
docker run -d --restart=always --name pr2_bot 000000
```

Проверьте, что контейнер запущен:
```bash
docker ps -a
```

Пример ответа:
```
CONTAINER ID   IMAGE          COMMAND                  CREATED         STATUS         PORTS     NAMES
5df687ebc2f6   000000         "python -u ./bot.py"     2 minutes ago   Up 2 minutes             pr2_bot
```

Посмотрите логи:
```bash
docker logs pr2_bot
```

Пример:
```
INFO:root:Bot started
INFO:maxapi:Polling started
```

Отправьте боту сообщение в MAX — проверьте, что он работает.

#### Шаг 10: Работа с Docker Registry

В учебном комплексе развёрнут локальный Docker Registry на порту 5050.

Отметьте образ для отправки в Registry:
```bash
docker tag 000000 <server-ip>:5050/pr2_bot:latest
```

Отправьте образ в Registry:
```bash
docker push <server-ip>:5050/pr2_bot:latest
```

Проверьте, что образ доступен:
```bash
curl http://<server-ip>:5050/v2/_catalog
```

Скачайте образ из Registry (эмуляция на другом хосте):
```bash
docker pull <server-ip>:5050/pr2_bot:latest
```

#### Шаг 11: Сохранение образа в архив

```bash
docker save -o pr2_bot.tar 000000
```

Скачайте файл `pr2_bot.tar` через файловый менеджер JupyterLab.

#### Шаг 12: Управление контейнером

Остановка и запуск:
```bash
docker stop pr2_bot
docker start pr2_bot
```

Удаление контейнера:
```bash
docker stop pr2_bot
docker rm pr2_bot
```

Удаление образа:
```bash
docker rmi 000000
```

---

## 📝 Приложение 1 (Справочное) Подготовка облачного сервера для Docker

Для самостоятельного изучения: развёртывание Docker на VPS.

- Виртуальные серверы: [RUVDS](https://ruvds.com/ru-rub/my/orders)
- Рекомендуемая ОС: Debian 12

### Установка Docker на Debian 12

```bash
apt-get update && apt-get upgrade -y
apt install htop nano
```

Создание пользователя:
```bash
useradd -m student -s /bin/bash
passwd student
```

Установка Docker Engine:
```bash
apt-get install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Добавление пользователя в группу docker:
```bash
groupadd docker
usermod -aG docker student
newgrp docker
docker run hello-world
```

---

## 📝 Приложение 2 (Справочное) Регистрация бота в мессенджере MAX

1. Откройте мессенджер MAX
2. Найдите пользователя **MasterBot**
3. Отправьте команду `/create`
4. Отправьте ник бота
5. Отправьте имя бота
6. Скопируйте токен

> 📌 Для подробностей см. [статью на Хабре](https://habr.com/ru/articles/930230/) и [Wiki библиотеки maxapi](https://github.com/love-apples/maxapi/wiki).

---

## 📝 Приложение 3 (Справочное) Основные команды Docker

| Команда | Описание |
|---------|----------|
| `docker build -t <name> .` | Сборка образа из Dockerfile |
| `docker run -d --name <name> <image>` | Запуск контейнера в фоне |
| `docker ps` | Список запущенных контейнеров |
| `docker ps -a` | Список всех контейнеров |
| `docker logs <container>` | Логи контейнера |
| `docker stop <container>` | Остановка контейнера |
| `docker start <container>` | Запуск контейнера |
| `docker rm <container>` | Удаление контейнера |
| `docker rmi <image>` | Удаление образа |
| `docker tag <image> <registry>/<name>:<tag>` | Пометка образа для Registry |
| `docker push <registry>/<name>:<tag>` | Отправка образа в Registry |
| `docker pull <registry>/<name>:<tag>` | Скачивание образа из Registry |
| `docker save -o <file.tar> <image>` | Сохранение образа в архив |
| `docker load -i <file.tar>` | Загрузка образа из архива |

---

## 📌 Отчёт о выполненной работе

1. Сохраните все выполненные шаги в вашем терминале
2. Сделайте скриншоты:
   - Запуск бота (`docker logs`)
   - Работоспособность бота в MAX
   - Результат `docker push` в Registry
3. Сохраните отчёт как `Pr_2_<группа>_<номер>.md` в формате Markdown
4. Загрузите файл в репозиторий `reports_<группа>_<номер>` в GitLab:

```bash
cp Pr_2_<группа>_<номер>.md .
git add .
git commit -m "Pr_2 report"
git push
```

**Финальное действие:**

Для запуска автоматической оценки создайте триггер-файл и отправьте его в репозиторий:

```bash
touch .grade-trigger
git add .grade-trigger
git commit -m "Grade trigger"
git push
```

> ⏳ Оценка запустится автоматически в GitLab CI. Результат появится в разделе **CI/CD → Pipelines**.

---

## Критерии оценки

| Критерий | Баллы |
|----------|-------|
| Бот для MAX создан и работает | 3 |
| Docker-образ собран | 2 |
| Контейнер запущен и бот работает в контейнере | 2 |
| Образ отправлен в Registry | 2 |
| Отчёт оформлен | 1 |
| **Итого** | **10** |
