#!/bin/bash
# Custom entrypoint for GitLab
# Generates gitlab.rb with all settings, then delegates to GitLab's init-container

set -e

cat > /etc/gitlab/gitlab.rb << RBEOF
# ============================================
# GitLab configuration (auto-generated at startup)
# ============================================

external_url "http://${GITLAB_EXTERNAL_IP}"
gitlab_rails['gitlab_shell_ssh_port'] = 2222

# Включаем саморегистрацию пользователей
gitlab_rails['sign_up_enabled'] = true
gitlab_rails['require_admin_approval_after_user_signup'] = false
gitlab_rails['require_user_email_confirmed'] = false
gitlab_rails['auto_verify_email_domains'] = ['*']
gitlab_rails['gitlab_email_enabled'] = false

# Nginx: слушать все интерфейсы
nginx['listen_addresses'] = ['0.0.0.0', '[::]']
nginx['listen_port'] = 80
nginx['proxy_read_timeout'] = 3600

# Полное отключение prometheus (mmap падает в /dev/shm)
prometheus_monitoring['enable'] = false
RBEOF

echo "GitLab config generated at /etc/gitlab/gitlab.rb"

# Delegate to original GitLab entrypoint
exec /assets/init-container "$@"
