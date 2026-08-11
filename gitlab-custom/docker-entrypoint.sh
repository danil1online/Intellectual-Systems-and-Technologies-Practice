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

# require_admin_approval_after_user_signup не маппится из gitlab.rb в БД ApplicationSettings.
# Устанавливаем через Rails console после reconfigure.
export GITLAB_POST_RECONFIGURE_SCRIPT='
echo "Setting require_admin_approval_after_user_signup = false via Rails console..."
gitlab-rails runner "
  s = ApplicationSetting.first_or_create
  if s.require_admin_approval_after_user_signup != false
    s.require_admin_approval_after_user_signup = false
    s.save!
    puts \"require_admin_approval_after_user_signup set to false\"
  else
    puts \"require_admin_approval_after_user_signup already false\"
  end
" 2>&1
'

# Delegate to original GitLab entrypoint
exec /assets/init-container "$@"
