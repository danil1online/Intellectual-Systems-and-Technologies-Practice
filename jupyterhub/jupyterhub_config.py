"""
JupyterHub конфигурация для учебного комплекса.
Авторизация: Keycloak OIDC.
Спавнер: LocalProcessSpawner с хуками первого входа.
"""

import os
import json
import datetime
import pwd
import subprocess
from pathlib import Path
from oauthenticator.generic import GenericOAuthenticator

# ============================================
# Основные настройки
# ============================================
c = get_config()

c.JupyterHub.bind_url = "http://0.0.0.0:8000"
c.JupyterHub.port = int(os.environ.get("JUPYTERHUB_PORT", "8000"))

# Секреты — используем env переменную или генерируем
cookie_secret_str = os.environ.get("JUPYTERHUB_COOKIE_SECRET")
if not cookie_secret_str:
    import secrets
    cookie_secret_str = secrets.token_hex(32)
    os.environ["JUPYTERHUB_COOKIE_SECRET"] = cookie_secret_str

c.JupyterHub.cookie_secret = bytes.fromhex(cookie_secret_str)
c.JupyterHub.db_url = "sqlite:///jupyterhub.db"

# Cookie settings для cross-domain OAuth
c.JupyterHub.cookie_options = {
    "samesite": os.environ.get("COOKIE_SAMESITE", "None"),
    "secure": os.environ.get("COOKIE_SECURE", "false").lower() == "true",
}

# ============================================
# Авторизация через Keycloak OAuth
# ============================================
HOST_IP = os.environ.get('HOST_IP', '10.8.1.3')
HOST_IP_LOCAL = os.environ.get('HOST_IP_LOCAL', 'localhost')
KEYCLOAK_PORT = os.environ.get('KEYCLOAK_PORT', '9200')
JUPYTERHUB_PORT = os.environ.get('JUPYTERHUB_PORT', '8000')

class CustomOAuthenticator(GenericOAuthenticator):
    username_claim = "preferred_username"
    scope = ["openid", "profile", "email"]
    tls_verify = False
    auto_login = True
    create_missing_users = True

    @property
    def issuer_url(self):
        return f"http://{HOST_IP}:{KEYCLOAK_PORT}/auth/realms/istp"

c.JupyterHub.authenticator_class = CustomOAuthenticator
c.CustomOAuthenticator.login_service = "Keycloak"

# INTERNAL URL: JupyterHub server → Keycloak (через Docker internal DNS)
c.CustomOAuthenticator.token_url = f"http://keycloak:{KEYCLOAK_PORT}/auth/realms/istp/protocol/openid-connect/token"
c.CustomOAuthenticator.userdata_url = f"http://keycloak:{KEYCLOAK_PORT}/auth/realms/istp/protocol/openid-connect/userinfo"

# EXTERNAL URL: браузер пользователя → Keycloak
c.CustomOAuthenticator.authorize_url = f"http://{HOST_IP}:{KEYCLOAK_PORT}/auth/realms/istp/protocol/openid-connect/auth"
c.CustomOAuthenticator.oauth_callback_url = f"http://{HOST_IP}:{JUPYTERHUB_PORT}/hub/oauth_callback"

c.CustomOAuthenticator.client_id = os.environ.get("JH_KEYCLOAK_CLIENT_ID", "jupyterhub")
c.CustomOAuthenticator.client_secret = os.environ.get("JH_KEYCLOAK_CLIENT_SECRET", "")

# Разрешить всех аутентифицированных пользователей
c.CustomOAuthenticator.allow_all = True
c.CustomOAuthenticator.admin_users = {
    "lecturer_01",
    "lecturer_02",
}

# ============================================
# Spawner — LocalProcessSpawner
# ============================================
from jupyterhub.spawner import LocalProcessSpawner

c.JupyterHub.spawner_class = LocalProcessSpawner

c.LocalProcessSpawner.cmd = ["jupyterhub-singleuser"]
c.LocalProcessSpawner.ip = "0.0.0.0"
c.LocalProcessSpawner.http_timeout = 120

# Environment переменные для singleuser
# JUPYTERHUB_API_TOKEN задаётся автоматически JupyterHub при спавне — НЕ перезаписывать!
c.Spawner.environment = {
    "JUPYTERHUB_USER": "",
    "LLM_MENTOR_TYPE": os.environ.get("LLM_MENTOR_TYPE", "local"),
    "LLM_MENTOR_BASE_URL": os.environ.get("LLM_MENTOR_BASE_URL", "http://llm:8080/v1"),
    "LLM_MENTOR_API_KEY": os.environ.get("LLM_MENTOR_API_KEY", "local-api-key"),
    "LLM_MENTOR_MODEL": os.environ.get("LLM_MENTOR_MODEL", "gpt-4o"),
    "LLM_CI_TYPE": os.environ.get("LLM_CI_TYPE", "local"),
    "LLM_CI_BASE_URL": os.environ.get("LLM_CI_BASE_URL", "http://llm:8080/v1"),
    "LLM_CI_API_KEY": os.environ.get("LLM_CI_API_KEY", "local-api-key"),
    "LLM_CI_MODEL": os.environ.get("LLM_CI_MODEL", "gpt-4o"),
    "GGUF_PATH": os.environ.get("GGUF_PATH", "/models/model.gguf"),
    "HF_HOME": "/hf-cache",
    "PIP_CACHE_DIR": "/shared/pip-cache",
}

# ============================================
# Хуки первого входа
# ============================================

def my_pre_spawn_hook(spawner):
    """Хук: выполняется перед спавном singleuser-сервера."""
    user = spawner.user
    # Системное имя: заменяем спецсимволы на underscore
    system_name = user.name.lower().replace("-", "_").replace(".", "_")
    user_home = f"/home/{system_name}"

    print(f"pre_spawn_hook: user={user.name}, system_name={system_name}, home={user_home}")

    # Создаём системного пользователя, если не существует
    try:
        pwd.getpwnam(system_name)
    except KeyError:
        print(f"Creating system user: {system_name}")
        result = subprocess.run(
            ["useradd", "-m", "-d", user_home, "-s", "/bin/bash", system_name],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode != 0:
            print(f"useradd error: {result.stderr}")
            raise RuntimeError(f"Failed to create system user {system_name}: {result.stderr}")

    os.makedirs(user_home, exist_ok=True)
    os.chmod(user_home, 0o755)

    # Добавляем лекторов в группу shared-packages для записи в кэши
    if system_name in ("lecturer_01", "lecturer_02"):
        try:
            subprocess.run(
                ["usermod", "-aG", "shared-packages", system_name],
                capture_output=True, text=True, timeout=10
            )
            for dir_path in ["/shared/pip-cache", "/hf-cache"]:
                os.makedirs(dir_path, exist_ok=True)
                subprocess.run(
                    ["chown", f"{uid}:shared-packages", dir_path],
                    capture_output=True, text=True, timeout=10
                )
        except Exception as e:
            print(f"Group assignment warning for {system_name}: {e}")

    # Символическая ссылка на общие данные
    data_link = f"{user_home}/data"
    if not os.path.exists(data_link):
        try:
            os.symlink("/shared/data", data_link)
        except FileExistsError:
            pass

    # Генерируем SSH-ключи для Git
    ssh_dir = f"{user_home}/.ssh"
    os.makedirs(ssh_dir, exist_ok=True)
    os.chmod(ssh_dir, 0o700)

    pub_key_path = os.path.join(ssh_dir, "id_ed25519.pub")
    priv_key_path = os.path.join(ssh_dir, "id_ed25519")
    if not os.path.exists(pub_key_path) or not os.path.exists(priv_key_path):
        try:
            cmd = [
                "ssh-keygen",
                "-t", "ed25519",
                "-f", priv_key_path,
                "-N", "",
                "-C", f"{system_name}@academic-platform",
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                os.chmod(priv_key_path, 0o600)
                os.chmod(pub_key_path, 0o644)
        except Exception as e:
            print(f"SSH key generation warning for {system_name}: {e}")

    # Устанавливаем права владения — рекурсивно на весь home
    try:
        pw = pwd.getpwnam(system_name)
        uid = pw.pw_uid
        gid = pw.pw_gid
        result = subprocess.run(
            ["chown", "-R", f"{uid}:{gid}", user_home],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            print(f"chown -R warning for {system_name}: {result.stderr}")
    except KeyError:
        print(f"Warning: system user {system_name} not found in passwd after creation")
    except Exception as e:
        print(f"Chown warning for {system_name}: {e}")

    spawner.environment["JUPYTERHUB_USER"] = system_name

c.LocalProcessSpawner.pre_spawn_hook = my_pre_spawn_hook

# ============================================
# Настройка IPython
# ============================================
c.LocalProcessSpawner.args = ["--no-browser"]
c.PromptManager.template = ""

# ============================================
# Jupyter AI
# ============================================
c.AiExtension.default_chat_model = ""
c.AiExtension.enabled = False
c.AiMagicsExtension.enabled = True

# ============================================
# Логирование
# ============================================
import logging
c.JupyterHub.log_level = logging.INFO

# ============================================
# Cleanup
# ============================================
c.JupyterHub.cleanup_servers = True
c.LocalProcessSpawner.notebook_dir = "~"
c.JupyterHub.cleanup_proxy = False
c.JupyterHub.default_url = "/hub/spawn"
