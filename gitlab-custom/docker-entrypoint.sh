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

# OIDC через Keycloak
gitlab_rails['omniauth_providers'] = [
  {
    name: 'openid_connect',
    label: 'Keycloak',
    issuer: "http://${OIDC_HOST_IP}:${KEYCLOAK_PORT:-9200}/auth/realms/istp",
    discovery: false,
    app_id: 'gitlab',
    app_secret: '${OIDC_GITLAB_SECRET}',
    scope: ['openid', 'profile', 'email'],
    redirect_uri: "http://${OIDC_HOST_IP}/users/auth/openid_connect/callback",
    authorization_endpoint: "http://${OIDC_HOST_IP}:9200/auth/realms/istp/protocol/openid-connect/auth",
    token_endpoint: "http://keycloak:9200/auth/realms/istp/protocol/openid-connect/token",
    userinfo_endpoint: "http://keycloak:9200/auth/realms/istp/protocol/openid-connect/userinfo",
    jwks_uri: "http://keycloak:9200/auth/realms/istp/protocol/openid-connect/certs",
    response_type: 'code',
    token_response_params: [],
    state: true,
    pkce: true,
    userInfoSignedResponseAlg: 'none',
    jwks_uri_verify: false,
    claim_options: {
      name: {
        map: ['preferred_username']
      },
      email: {
        map: ['email']
      },
      first_name: {
        map: ['given_name']
      },
      last_name: {
        map: ['family_name']
      }
    },
    attribute_links: {
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier' => 'uid'
    },
    disable_ui: false
  }
]
gitlab_rails['omniauth_enabled'] = true
gitlab_rails['omniauth_allow_single_sign_on'] = ['openid_connect']
gitlab_rails['omniauth_auto_link_user'] = true
gitlab_rails['omniauth_auto_link_user_id_token'] = true
gitlab_rails['omniauth_auto_link_user_with_same_email'] = true
gitlab_rails['omniauth_sync_email_from_provider'] = ['openid_connect']
gitlab_rails['omniauth_sync_profile_from_provider'] = ['openid_connect']
gitlab_rails['omniauth_sync_profile_attributes'] = ['openid_connect']
gitlab_rails['omniauth_allowed_request_methods'] = ['get', 'post']

# Локальный вход сохраняется при наличии OIDC-провайдеров
gitlab_rails['omniauth_block_auto_created_users'] = false

# Полное отключение prometheus (mmap падает в /dev/shm)
prometheus_monitoring['enable'] = false
RBEOF

echo "GitLab config generated at /etc/gitlab/gitlab.rb"

# Delegate to original GitLab entrypoint
exec /assets/init-container "$@"
