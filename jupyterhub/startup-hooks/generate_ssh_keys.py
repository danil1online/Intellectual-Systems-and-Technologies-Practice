#!/usr/bin/env python3
"""
Генерация SSH-ключа при первом входе студента.
Запускается как хук в JupyterHub.
"""

import os
import subprocess
import pwd
import stat

def generate_ssh_key(username):
    """Генерировать SSH-ключ Ed25519 для пользователя."""
    try:
        user_info = pwd.getpwnam(username)
        home_dir = user_info.pw_dir
    except KeyError:
        home_dir = f"/home/{username}"

    ssh_dir = os.path.join(home_dir, ".ssh")
    os.makedirs(ssh_dir, mode=0o700, exist_ok=True)

    pub_key_path = os.path.join(ssh_dir, "id_ed25519.pub")
    priv_key_path = os.path.join(ssh_dir, "id_ed25519")

    # Если ключ уже существует — пропускаем
    if os.path.exists(pub_key_path) and os.path.exists(priv_key_path):
        return

    # Генерируем ключ
    cmd = [
        "ssh-keygen",
        "-t", "ed25519",
        "-f", priv_key_path,
        "-N", "",
        "-C", f"{username}@academic-platform",
    ]

    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=10)
        os.chmod(priv_key_path, 0o600)
        os.chmod(pub_key_path, 0o644)

        # Устанавливаем владельца
        os.chown(ssh_dir, user_info.pw_uid, user_info.pw_gid)
        os.chown(priv_key_path, user_info.pw_uid, user_info.pw_gid)
        os.chown(pub_key_path, user_info.pw_uid, user_info.pw_gid)

        print(f"SSH-ключ сгенерирован для {username}")
        print(f"Публичный ключ для добавления в GitLab:")
        with open(pub_key_path) as f:
            print(f.read().strip())
    except subprocess.TimeoutExpired:
        print(f"Ошибка: таймаут генерации SSH-ключа для {username}")
    except Exception as e:
        print(f"Ошибка генерации SSH-ключа: {e}")


if __name__ == "__main__":
    username = os.environ.get("JUPYTERHUB_USER", "")
    if username:
        generate_ssh_key(username)
    else:
        print("JUPYTERHUB_USER не задан. Запуск через JupyterHub hook.")
