#!/bin/bash
# ============================================
# Инициализация Keycloak для учебного комплекса
# ============================================

set -e

# Загрузка переменных окружения из .env
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
fi

KEYCLOAK_URL="http://localhost:9200/auth"
KC_ADMIN_USER="${KC_ADMIN_USER:-admin}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD}"

echo "=== Ожидание запуска Keycloak ==="
for i in {1..60}; do
  if curl -sf "$KEYCLOAK_URL/realms/master/.well-known/openid-configuration" > /dev/null 2>&1; then
    echo "Keycloak доступен!"
    break
  fi
  echo "Ожидание... ($i/60)"
  sleep 2
done

echo "=== Получение admin токена ==="
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=$KC_ADMIN_USER" \
  -d "password=$KC_ADMIN_PASSWORD" \
  -d "grant_type=password" | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "ERROR: Не удалось получить admin token"
  exit 1
fi
echo "Admin token получен"

echo "=== Создание realm istp ==="
# Создаем минимальный realm
curl -s -X POST "$KEYCLOAK_URL/admin/realms" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"realm":"istp","enabled":true}' | jq .

# Проверяем что realm создан
sleep 2
REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/realms/istp")
if [ "$REALM_EXISTS" != "200" ]; then
  echo "ERROR: Realm istp не создан"
  exit 1
fi
echo "Realm istp создан"

echo "=== Настройка realm istp ==="
REALM_ID=$(curl -s "http://localhost:9200/auth/admin/realms/istp" -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.id')

# Обновляем настройки realm
curl -s -X PUT "$KEYCLOAK_URL/admin/realms/istp" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"id\":\"$REALM_ID\",\"realm\":\"istp\",\"enabled\":true,\"registrationAllowed\":true,\"registrationEmailAsUsername\":false,\"editUsernameAllowed\":true,\"passwordPolicy\":\"length(8) and notUsername(undefined) and lowerCase(1) and digits(1)\",\"loginWithEmailAllowed\":true,\"duplicateEmailsAllowed\":false,\"resetPasswordAllowed\":true,\"bruteForceProtected\":false,\"permanentLockout\":false,\"loginTheme\":\"keycloak\",\"accountTheme\":\"keycloak\",\"adminTheme\":\"keycloak\",\"webAuthnPolicyRpEntityName\":\"keycloak\",\"webAuthnPolicySignatureAlgorithms\":[\"ES256\"],\"webAuthnPolicyUserVerificationRequirement\":\"required\",\"webAuthnPolicyCreateTimeout\":0,\"webAuthnPolicyAttestationConveyancePreference\":\"not specified\",\"webAuthnPolicyAuthenticatorAttachment\":\"not specified\",\"webAuthnPolicyRequireResidentKey\":\"yes\",\"webAuthnPolicyUserExistenceTransferLimit\":0,\"webAuthnPolicyPasswordlessRpEntityName\":\"keycloak\",\"webAuthnPolicyPasswordlessSignatureAlgorithms\":[\"ES256\"],\"webAuthnPolicyPasswordlessUserVerificationRequirement\":\"required\",\"webAuthnPolicyPasswordlessCreateTimeout\":0,\"webAuthnPolicyPasswordlessAttestationConveyancePreference\":\"not specified\",\"webAuthnPolicyPasswordlessAuthenticatorAttachment\":\"not specified\",\"webAuthnPolicyPasswordlessRequireResidentKey\":\"yes\",\"webAuthnPolicyPasswordlessUserExistenceTransferLimit\":0,\"eventsEnabled\":true,\"eventsListeners\":[\"jboss-logging\"],\"enabledEventTypes\":[\"LOGIN_ERROR\",\"LOGIN\",\"LOGOUT\",\"REGISTER\",\"CODE_TO_TOKEN\",\"CUSTOM_REQUIRED_ACTION\",\"UPDATE_CONSENT_ERROR\",\"UPDATE_TPM_ERROR\",\"CLIENT_LOGIN\",\"REFRESH_TOKEN\"],\"adminEventsEnabled\":true,\"adminEventsDetailsEnabled\":true}" | jq .

echo "Realm istp настроен"

echo "=== Создание OAuth клиентов ==="

# JupyterHub client
JH_CLIENT_ID="jupyterhub"
JH_CLIENT_SECRET=$(openssl rand -hex 32)
curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"$JH_CLIENT_ID\",\"name\":\"JupyterHub\",\"enabled\":true,\"clientAuthenticatorType\":\"client-secret\",\"redirectUris\":[\"http://localhost:8000/hub/oauth_callback\"],\"webOrigins\":[\"+\"],\"protocol\":\"openid-connect\",\"standardFlowEnabled\":true,\"implicitFlowEnabled\":false,\"directAccessGrantsEnabled\":false,\"serviceAccountsEnabled\":false,\"publicClient\":false,\"frontchannelLogout\":true,\"consentRequired\":false,\"defaultClientScopes\":[\"web-origins\",\"role_list\",\"profile\",\"email\",\"roles\"],\"optionalClientScopes\":[\"address\",\"phone\",\"offline_access\",\"microprofile-jwt\"],\"secret\":\"$JH_CLIENT_SECRET\"}" | jq .
echo "JupyterHub Client ID: $JH_CLIENT_ID"
echo "JupyterHub Client Secret: $JH_CLIENT_SECRET"

# Admin Dashboard client
DASH_CLIENT_ID="admin-dashboard"
DASH_CLIENT_SECRET=$(openssl rand -hex 32)
curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"$DASH_CLIENT_ID\",\"name\":\"Admin Dashboard\",\"enabled\":true,\"clientAuthenticatorType\":\"client-secret\",\"redirectUris\":[\"http://localhost:9000/callback\"],\"webOrigins\":[\"+\"],\"protocol\":\"openid-connect\",\"standardFlowEnabled\":true,\"implicitFlowEnabled\":false,\"directAccessGrantsEnabled\":false,\"serviceAccountsEnabled\":false,\"publicClient\":false,\"frontchannelLogout\":true,\"consentRequired\":false,\"defaultClientScopes\":[\"web-origins\",\"role_list\",\"profile\",\"email\",\"roles\"],\"optionalClientScopes\":[\"address\",\"phone\",\"offline_access\",\"microprofile-jwt\"],\"secret\":\"$DASH_CLIENT_SECRET\"}" | jq .
echo "Admin Dashboard Client ID: $DASH_CLIENT_ID"
echo "Admin Dashboard Client Secret: $DASH_CLIENT_SECRET"

# Nextcloud client
NC_CLIENT_ID="nextcloud"
NC_CLIENT_SECRET=$(openssl rand -hex 32)
curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"$NC_CLIENT_ID\",\"name\":\"Nextcloud\",\"enabled\":true,\"clientAuthenticatorType\":\"client-secret\",\"redirectUris\":[\"http://localhost:8080/\"],\"webOrigins\":[\"+\"],\"protocol\":\"openid-connect\",\"standardFlowEnabled\":true,\"implicitFlowEnabled\":false,\"directAccessGrantsEnabled\":false,\"serviceAccountsEnabled\":false,\"publicClient\":false,\"frontchannelLogout\":true,\"consentRequired\":false,\"defaultClientScopes\":[\"web-origins\",\"role_list\",\"profile\",\"email\",\"roles\"],\"optionalClientScopes\":[\"address\",\"phone\",\"offline_access\",\"microprofile-jwt\"],\"secret\":\"$NC_CLIENT_SECRET\"}" | jq .
echo "Nextcloud Client ID: $NC_CLIENT_ID"
echo "Nextcloud Client Secret: $NC_CLIENT_SECRET"

# GitLab client
GITLAB_CLIENT_ID="gitlab"
GITLAB_CLIENT_SECRET=$(openssl rand -hex 32)
curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"$GITLAB_CLIENT_ID\",\"name\":\"GitLab\",\"enabled\":true,\"clientAuthenticatorType\":\"client-secret\",\"redirectUris\":[\"http://localhost/users/auth/keycloak/callback\"],\"webOrigins\":[\"+\"],\"protocol\":\"openid-connect\",\"standardFlowEnabled\":true,\"implicitFlowEnabled\":false,\"directAccessGrantsEnabled\":false,\"serviceAccountsEnabled\":false,\"publicClient\":false,\"frontchannelLogout\":true,\"consentRequired\":false,\"defaultClientScopes\":[\"web-origins\",\"role_list\",\"profile\",\"email\",\"roles\"],\"optionalClientScopes\":[\"address\",\"phone\",\"offline_access\",\"microprofile-jwt\"],\"secret\":\"$GITLAB_CLIENT_SECRET\"}" | jq .
echo "GitLab Client ID: $GITLAB_CLIENT_ID"
echo "GitLab Client Secret: $GITLAB_CLIENT_SECRET"

echo "=== Сохранение client secrets ==="
mkdir -p shared/config
cat > shared/config/keycloak-clients.json << EOF
{
  "jupyterhub": {
    "client_id": "$JH_CLIENT_ID",
    "client_secret": "$JH_CLIENT_SECRET",
    "redirect_uri": "http://localhost:8000/hub/oauth_callback"
  },
  "admin-dashboard": {
    "client_id": "$DASH_CLIENT_ID",
    "client_secret": "$DASH_CLIENT_SECRET",
    "redirect_uri": "http://localhost:9000/callback"
  },
  "nextcloud": {
    "client_id": "$NC_CLIENT_ID",
    "client_secret": "$NC_CLIENT_SECRET",
    "redirect_uri": "http://localhost:8080/"
  },
  "gitlab": {
    "client_id": "$GITLAB_CLIENT_ID",
    "client_secret": "$GITLAB_CLIENT_SECRET",
    "redirect_uri": "http://localhost/users/auth/keycloak/callback"
  }
}
EOF

echo "=== Client secrets сохранены в shared/config/keycloak-clients.json ==="
echo "=== Инициализация Keycloak завершена ==="
