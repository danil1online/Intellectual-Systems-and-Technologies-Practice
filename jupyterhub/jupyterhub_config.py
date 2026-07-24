"""
JupyterHub конфигурация для учебного комплекса.
Авторизация: GitLab через Zitadel OIDC.
Автор спавна: SimpleSpawner с хуками первого входа.
"""

import os
import json
import datetime
from pathlib import Path
from oauthenticator.zitadel import ZitadelOAuthenticator

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
# Авторизация через Zitadel OAuth
# ============================================
c.JupyterHub.authenticator_class = ZitadelOAuthenticator

# Zitadel OAuth конфигурация
c.ZitadelOAuthenticator.zitadel_url = os.environ.get("ZITADEL_ISSUER_URL", "http://zitadel:9200")
c.ZitadelOAuthenticator.client_id = os.environ.get("JH_ZITADEL_CLIENT_ID", "placeholder")
c.ZitadelOAuthenticator.client_secret = os.environ.get("JH_ZITADEL_CLIENT_SECRET", "placeholder")
c.ZitadelOAuthenticator.zitadel_instance_url = os.environ.get("ZITADEL_ISSUER_URL", "http://zitadel:9200")

# Автоматическое создание пользователя при OAuth-входе (ключевой параметр)
c.ZitadelOAuthenticator.create_missing_users = True
c.ZitadelOAuthenticator.allow_all = True

# OAuth callback
c.ZitadelOAuthenticator.oauth_callback_url = os.path.join(
    os.environ.get("OAUTH2_REDIRECT_URI", "http://localhost:8000/hub/oauth_callback")
)

# Захват email из OIDC токена
c.ZitadelOAuthenticator.scope = ["openid", "profile", "email"]
c.ZitadelOAuthenticator.username_key = "preferred_username"

# Связывание username GitLab с JupyterHub
def normalize_username(username):
    """Нормализация имени пользователя для JupyterHub."""
    return username.lower().replace("-", "_").replace(".", "_")

c.ZitadelOAuthenticator.username_normalize = "lowercase"

# ============================================
# Spawner — SimpleSpawner
# ============================================
from jupyterhub.spawner import SimpleSpawner

c.JupyterHub.spawner_class = SimpleSpawner

c.SimpleSpawner.cmd = ["jupyter-lab"]
c.SimpleSpawner.ip = "127.0.0.1"
c.SimpleSpawner.port = 0

# Домашняя директория студента
def get_user_home_dir(user):
    """Определение домашней директории для пользователя."""
    username = user.name.lower().replace("-", "_").replace(".", "_")
    return f"/home/{username}"

c.SimpleSpawner.home_dir = "/home"

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

# Копирование шаблонов notebooks при первом входе пользователя
@c.Spawner.pre_spawn_start
def pre_spawn_start(spawner, user):
    """Хук: выполняется перед спавном контейнера."""
    username = user.name.lower().replace("-", "_").replace(".", "_")
    user_home = f"/home/{username}"
    notebooks_dir = f"{user_home}/notebooks"
    shared_data_dir = "/app/notebooks"
    shared_logs_dir = "/app/logs"

    # Создаём домашнюю директорию если не существует
    import os
    os.makedirs(user_home, exist_ok=True)
    os.makedirs(notebooks_dir, exist_ok=True)
    os.chmod(user_home, 0o755)

    # Копируем шаблоны практических работ при первом входе
    template_files = []
    try:
        for f in os.listdir(shared_data_dir):
            if f.endswith(".ipynb"):
                template_files.append(f)
    except FileNotFoundError:
        pass

    if template_files:
        copied = 0
        for template in template_files:
            src = os.path.join(shared_data_dir, template)
            dst = os.path.join(notebooks_dir, template)
            if not os.path.exists(dst):
                import shutil
                shutil.copy2(src, dst)
                copied += 1
        if copied > 0:
            spawner.log.info(f"Скопировано {copied} шаблонов для пользователя {username}")

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


# ============================================
# Настройка IPython для singleuser
# ============================================
c.Spawner.args = ["--no-browser"]

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
c.Spawner.notebook_dir = "~"

# ============================================
# Proxy
# ============================================
c.JupyterHub.cleanup_proxy = False
c.JupyterHub.default_server = True
