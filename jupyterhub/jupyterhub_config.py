"""
JupyterHub конфигурация для учебного комплекса.
Авторизация: GitLab через Keycloak OIDC.
Автор спавна: LocalProcessSpawner с хуками первого входа.
"""

import os
import json
import datetime
from pathlib import Path
from oauthenticator.generic import GenericOAuthenticator

# ============================================
# Основные настройки
# ============================================
c = get_config()

c.JupyterHub.bind_url = "http://0.0.0.0:8000"
c.JupyterHub.ip = "0.0.0.0"
c.JupyterHub.port = int(os.environ.get("JUPYTERHUB_PORT", "8000"))

# Секреты
secret_file = Path("/app/jupyterhub_cookie_secret")
if not secret_file.exists():
    import secrets
    secret_file.write_text(secrets.token_hex(32))
    os.chmod(secret_file, 0o600)

c.JupyterHub.cookie_secret_file = str(secret_file)
c.JupyterHub.db_url = "sqlite:///jupyterhub.db"

# ============================================
# Авторизация через Keycloak OAuth
# ============================================
c.JupyterHub.authenticator_class = GenericOAuthenticator

# Keycloak OAuth конфигурация
c.GenericOAuthenticator.login_service = "Keycloak"
c.GenericOAuthenticator.authorize_url = os.environ.get("KEYCLOAK_ISSUER", "http://keycloak:8080/auth/realms/istp") + "/protocol/openid-connect/auth"
c.GenericOAuthenticator.token_url = os.environ.get("KEYCLOAK_ISSUER", "http://keycloak:8080/auth/realms/istp") + "/protocol/openid-connect/token"
c.GenericOAuthenticator.userdata_url = os.environ.get("KEYCLOAK_ISSUER", "http://keycloak:8080/auth/realms/istp") + "/protocol/openid-connect/userinfo"
c.GenericOAuthenticator.client_id = os.environ.get("JH_KEYCLOAK_CLIENT_ID", "jupyterhub")
c.GenericOAuthenticator.client_secret = os.environ.get("JH_KEYCLOAK_CLIENT_SECRET", "")
c.GenericOAuthenticator.oauth_callback_url = os.environ.get("OAUTH2_REDIRECT_URI", "http://localhost:8000/hub/oauth_callback")
# Force full URL (env may contain just path)
if not c.GenericOAuthenticator.oauth_callback_url.startswith("http"):
    c.GenericOAuthenticator.oauth_callback_url = f"http://localhost:{c.JupyterHub.port}{c.GenericOAuthenticator.oauth_callback_url}"
c.GenericOAuthenticator.username_key = "preferred_username"
c.GenericOAuthenticator.scope = ["openid", "profile", "email"]
c.GenericOAuthenticator.tls_verify = False

# Автоматическое создание пользователя при OAuth-входе (ключевой параметр)
c.GenericOAuthenticator.create_missing_users = True
c.GenericOAuthenticator.auto_login = True
c.GenericOAuthenticator.normalize_username = lambda username: username.lower().replace("-", "_").replace(".", "_")

# ============================================
# Spawner — LocalProcessSpawner
# ============================================
from jupyterhub.spawner import LocalProcessSpawner

c.JupyterHub.spawner_class = LocalProcessSpawner

c.LocalProcessSpawner.cmd = ["jupyter-lab"]
c.LocalProcessSpawner.ip = "127.0.0.1"
c.LocalProcessSpawner.port = 0

# Домашняя директория студента
def get_user_home_dir(user):
    """Определение домашней директории для пользователя."""
    username = user.name.lower().replace("-", "_").replace(".", "_")
    return f"/home/{username}"

# Note: LocalProcessSpawner uses system home directories by default

# Environment переменные для singleuser
c.Spawner.environment = {
    "JUPYTERHUB_USER": "",  # будет установлено JupyterHub
    "JUPYTERHUB_API_TOKEN": os.environ.get("JH_API_TOKEN", ""),
    "JUPYTERHUB_HOST": "0.0.0.0",
    "JUPYTERHUB_PORT": os.environ.get("JUPYTERHUB_PORT", "8000"),
    "JUPYTERHUB_OAUTH_CALLBACK_URL": "/hub/oauth_callback",
    "LLM_MENTOR_TYPE": os.environ.get("LLM_MENTOR_TYPE", "local"),
    "LLM_MENTOR_BASE_URL": os.environ.get("LLM_MENTOR_BASE_URL", "http://llm:8080/v1"),
    "LLM_MENTOR_API_KEY": os.environ.get("LLM_MENTOR_API_KEY", "local-api-key"),
    "LLM_CI_TYPE": os.environ.get("LLM_CI_TYPE", "local"),
    "LLM_CI_BASE_URL": os.environ.get("LLM_CI_BASE_URL", "http://llm:8080/v1"),
    "LLM_CI_API_KEY": os.environ.get("LLM_CI_API_KEY", "local-api-key"),
    "GGUF_PATH": os.environ.get("GGUF_PATH", "/models/Qwen3.5-0.8B-Q4_K_M.gguf"),
}

# ============================================
# Хуки первого входа
# ============================================

def my_pre_spawn_hook(spawner, user):
    """Хук: выполняется перед спавном контейнера."""
    username = user.name.lower().replace("-", "_").replace(".", "_")
    user_home = f"/home/{username}"

    # Создаём домашнюю директорию если не существует
    import os
    os.makedirs(user_home, exist_ok=True)
    os.chmod(user_home, 0o755)

    # Создаём symlink для общих данных
    data_link = f"{user_home}/data"
    if not os.path.exists(data_link):
        os.symlink("/shared/data", data_link)

    # Настраиваем IPython startup
    startup_dir = f"{user_home}/.ipython/profile_default/startup"
    os.makedirs(startup_dir, exist_ok=True)

    # Копируем 00_mentor.py
    mentor_startup = "/app/startup/00_mentor.py"
    dst_startup = f"{startup_dir}/00_mentor.py"
    if os.path.exists(mentor_startup) and not os.path.exists(dst_startup):
        import shutil
        shutil.copy2(mentor_startup, dst_startup)

    # Настраиваем SSH-директорию
    ssh_dir = f"{user_home}/.ssh"
    os.makedirs(ssh_dir, exist_ok=True)
    os.chmod(ssh_dir, 0o700)

    # Устанавливаем владельца
    try:
        import pwd
        pw = pwd.getpwnam(username)
        uid = pw.pw_uid
        gid = pw.pw_gid
        os.chown(user_home, uid, gid)
        os.chown(startup_dir, uid, gid, follow_symlinks=False)
        os.chown(ssh_dir, uid, gid)
    except KeyError:
        pass

    # Сохраняем username для environment
    spawner.environment["JUPYTERHUB_USER"] = username

# Устанавливаем хук первого входа
c.LocalProcessSpawner.pre_spawn_hook = my_pre_spawn_hook


# ============================================
# Настройка IPython для singleuser
# ============================================
c.LocalProcessSpawner.args = ["--no-browser"]

# IPython конфигурация
c.PromptManager.template = ""

# ============================================
# Jupyter AI конфигурация
# ============================================

# Отключаем стандартный чат Jupyter-AI (используем только %%ask_mentor)
c.AiExtension.default_chat_model = ""
c.AiExtension.enabled = False

# Но разрешаем %%ai магические команды для %%ask_mentor (он определяется отдельно)
c.AiMagicsExtension.enabled = True

# Настройка модели для %%ask_mentor (через переменные окружения)
# Модель определяется в 00_mentor.py через OPENAI_API_BASE_URL

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

# ============================================
# Proxy
# ============================================
c.JupyterHub.cleanup_proxy = False
c.JupyterHub.default_server = True
