#!/bin/bash
# Custom entrypoint for GitLab
# Generates gitlab.rb with all settings, then delegates to GitLab's init-container

set -e

cat > /etc/gitlab/gitlab.rb << RBEOF
# ============================================
# GitLab configuration (auto-generated at startup)
# ============================================

external_url "http://${OIDC_HOST_IP}"
gitlab_rails['gitlab_shell_ssh_port'] = 2222

# Автоматическое подтверждение пользователей и email
gitlab_rails['require_admin_approval_after_user_signup'] = false
gitlab_rails['require_user_email_confirmed'] = false
gitlab_rails['omniauth_block_auto_created_users'] = false
gitlab_rails['auto_verify_email_domains'] = ['*']
gitlab_rails['gitlab_email_enabled'] = false

# Nginx: слушать все интерфейсы
nginx['listen_addresses'] = ['0.0.0.0', '[::]']
nginx['listen_port'] = 80
nginx['proxy_read_timeout'] = 3600

# ============================================
# SLO: RemoteUser через OAuth2-Proxy
# ============================================
# GitLab принимает пользователя из заголовка X-Forwarded-User от OAuth2-Proxy
# Отключаем OmniAuth полностью — аутентификация через OAuth2-Proxy
gitlab_rails['omniauth_providers'] = []
gitlab_rails['omniauth_enabled'] = false

# Разрешаем создание пользователей без аутентификации
gitlab_rails['omniauth_block_auto_created_users'] = false
gitlab_rails['omniauth_auto_link_user'] = true
gitlab_rails['omniauth_auto_link_user_id_token'] = true
gitlab_rails['omniauth_auto_link_user_with_same_email'] = true

# Полное отключение prometheus (mmap падает в /dev/shm)
prometheus_monitoring['enable'] = false
RBEOF

echo "GitLab config generated at /etc/gitlab/gitlab.rb"

# Delegate to original GitLab entrypoint
exec /assets/init-container "$@"
