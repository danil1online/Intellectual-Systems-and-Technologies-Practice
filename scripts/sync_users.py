#!/usr/bin/env python3
"""
Sync Users: GitLab → Zitadel
Синхронизация пользователей GitLab с Zitadel через SCIM API.
Запускается как cron-job или при старте контейнера.
"""

import os
import sys
import json
import time
import requests
from datetime import datetime, timezone

GITLAB_URL = os.environ.get("GITLAB_URL", "http://gitlab:80")
GITLAB_TOKEN = os.environ.get("GITLAB_ADMIN_TOKEN", "placeholder")
ZITADEL_API = os.environ.get("ZITADEL_API_URL", "http://zitadel:9200")
ZITADEL_TOKEN = os.environ.get("ZITADEL_ADMIN_TOKEN", "")

LOG_FILE = os.environ.get("LOG_FILE", "/app/logs/user_sync.log")


def log(msg: str):
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    line = f"[{timestamp}] {msg}"
    print(line)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def get_gitlab_users():
    """Получить всех пользователей GitLab кроме root и системных."""
    users = []
    page = 1
    per_page = 100

    while True:
        try:
            resp = requests.get(
                f"{GITLAB_URL}/api/v4/users",
                params={"per_page": per_page, "page": page},
                headers={"PRIVATE-TOKEN": GITLAB_TOKEN},
                timeout=30,
            )
            if resp.status_code != 200:
                log(f"⚠ GitLab API error: {resp.status_code} {resp.text}")
                break

            page_users = resp.json()
            if not page_users:
                break

            for u in page_users:
                # Пропускаем root и системных ботов
                if u["username"] in ("root", "GitLabDuo", "gitlab-ci", "deploy-bot"):
                    continue
                users.append(u)

            if len(page_users) < per_page:
                break
            page += 1

        except Exception as e:
            log(f"Ошибка получения пользователей GitLab: {e}")
            break

    return users


def sync_users(users: list):
    """Синхронизировать пользователей через SCIM API Zitadel."""
    if not ZITADEL_TOKEN:
        log("⚠ ZITADEL_ADMIN_TOKEN не задан, синхронизация пропущена.")
        return

    synced = 0
    errors = 0

    for user in users:
        username = user["username"]
        email = user["email"]
        name = user.get("name", username)

        try:
            # Проверяем, существует ли пользователь в Zitadel
            # Zitadel SCIM: GET /v1/scim/v2/Users?filter=userName eq '{username}'
            scim_resp = requests.get(
                f"{ZITADEL_API}/v1/scim/v2/Users",
                params={"filter": f"userName eq '{username}'"},
                headers={
                    "Authorization": f"Bearer {ZITADEL_TOKEN}",
                    "Content-Type": "application/scim+json",
                },
                timeout=10,
            )

            if scim_resp.status_code == 200:
                scim_data = scim_resp.json()
                if scim_data.get("totalResults", 0) > 0:
                    log(f"  Пользователь {username} уже существует в Zitadel")
                    synced += 1
                    continue

            # Создаём пользователя в Zitadel через SCIM
            scim_body = {
                "schemas": ["urn:ietf:params:scim:schemas:core:2.0:User"],
                "userName": username,
                "name": {"familyName": name.split()[-1] if " " in name else username,
                         "givenName": " ".join(name.split()[:-1]) or username},
                "emails": [{"value": email, "primary": True}],
                "active": True,
            }

            create_resp = requests.post(
                f"{ZITADEL_API}/v1/scim/v2/Users",
                json=scim_body,
                headers={
                    "Authorization": f"Bearer {ZITADEL_TOKEN}",
                    "Content-Type": "application/scim+json",
                },
                timeout=10,
            )

            if create_resp.status_code in (200, 201):
                log(f"  ✓ Создан пользователь {username} ({email})")
                synced += 1
            else:
                log(f"  ⚠ Ошибка создания {username}: {create_resp.status_code} {create_resp.text}")
                errors += 1

        except Exception as e:
            log(f"  ✗ Ошибка при синхронизации {username}: {e}")
            errors += 1

    log(f"Синхронизация завершена: {synced} синхронизировано, {errors} ошибок")


def main():
    log("=== Start user sync ===")
    users = get_gitlab_users()
    log(f"Найдено {len(users)} пользователей GitLab")

    if users:
        sync_users(users)
    else:
        log("Нет пользователей для синхронизации")

    log("=== End user sync ===")


if __name__ == "__main__":
    main()
