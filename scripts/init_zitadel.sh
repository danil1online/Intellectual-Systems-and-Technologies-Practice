#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Инициализация Zitadel: создание OIDC клиентов
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

source .env

ZITADEL_GRPC_HOST="http://zitadel:9200"
ZITADEL_ADMIN_USER="__admin__"
ZITADEL_ADMIN_PASSWORD="$ZITADEL_ADMIN_PASSWORD"
ZITADEL_INSTANCE_HOST="http://zitadel:9200"

echo "=== Zitadel: получение access token ==="

# Zitadel требует авторизации через API ключ или username/password
# Для начальной авторизации используем admin credentials
ZITADEL_TOKEN=$(curl -s --request POST "$ZITADEL_GRPC_HOST/_/oauth/token" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data "grant_type=client_credentials" \
  --data "client_id=admin" \
  --data "client_secret=$ZITADEL_ADMIN_PASSWORD" \
  | jq -r '.access_token')

if [[ -z "$ZITADEL_TOKEN" || "$ZITADEL_TOKEN" == "null" ]]; then
    echo "Заметание: Zitadel ещё не полностью готов, пробуем с admin user..."

    # Альтернативный подход: Zitadel самозарегистрирован при первом запуске
    # Используем default admin credentials
    ZITADEL_TOKEN=$(curl -s --request POST "$ZITADEL_GRPC_HOST/_/oauth/token" \
      --header "Content-Type: application/x-www-form-urlencoded" \
      --data "grant_type=password" \
      --data "username=$ZITADEL_ADMIN_USER" \
      --data "password=$ZITADEL_ADMIN_PASSWORD" \
      --data "scope=openid" \
      | jq -r '.access_token')
fi

if [[ -z "$ZITADEL_TOKEN" || "$ZITADEL_TOKEN" == "null" ]]; then
    echo "⚠ Zitadel не ответил. OIDC клиенты будут настроены вручную через UI."
    echo "  Zitadel URL: http://localhost:$ZITADEL_PORT"
    echo "  Admin user:  __admin__"
    echo "  Admin pass:  $ZITADEL_ADMIN_PASSWORD"
    exit 0
fi

echo "✓ Zitadel token получен"

echo ""
echo "=== Zitadel: получение instance ID ==="

INSTANCE_ID=$(curl -s --request GET "$ZITADEL_GRPC_HOST/admin/v1/instances/me" \
  --header "Authorization: Bearer $ZITADEL_TOKEN" \
  | jq -r '.instanceId' 2>/dev/null || echo "")

if [[ -z "$INSTANCE_ID" ]]; then
    # Попробуем другой endpoint
    INSTANCE_ID=$(curl -s --request GET "$ZITADEL_GRPC_PATH/admin/v1/instances/me" \
      --header "Authorization: Bearer $ZITADEL_TOKEN" | jq -r '.id' 2>/dev/null || echo "")
fi

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "null" ]]; then
    INSTANCE_ID="default"
    echo "⚠ Instance ID не найден, используем default"
fi

echo "✓ Instance: $INSTANCE_ID"

echo ""
echo "=== Zitadel: создание OIDC клиента для JupyterHub ==="

JH_CLIENT=$(curl -s --request POST "$ZITADEL_GRPC_HOST/management/v1/users/me/apps/oauth/client" \
  --header "Authorization: Bearer $ZITADEL_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"name\": \"jupyterhub\",
    \"redirectUris\": [
      \"http://localhost:$JUPYTERHUB_PORT/hub/oauth_callback\",
      \"http://jupyterhub:8000/hub/oauth_callback\"
    ],
    \"response_types\": [\"code\"],
    \"grant_types\": [\"authorization_code\", \"refresh_token\"],
    \"app_type\": \"web\",
    \"auth_method\": \"client_secret_basic\"
  }" 2>/dev/null)

JH_CLIENT_ID=$(echo "$JH_CLIENT" | jq -r '.clientId' 2>/dev/null || echo "placeholder")
JH_CLIENT_SECRET=$(echo "$JH_CLIENT" | jq -r '.clientSecret' 2>/dev/null || echo "placeholder")

if [[ "$JH_CLIENT_ID" == "null" || -z "$JH_CLIENT_ID" ]]; then
    JH_CLIENT_ID="placeholder"
    JH_CLIENT_SECRET="placeholder"
    echo "⚠ Не удалось создать JupyterHub OIDC клиент через API"
else
    # Обновляем .env
    sed -i "s/^JH_ZITADEL_CLIENT_ID=.*/JH_ZITADEL_CLIENT_ID=$JH_CLIENT_ID/" .env
    sed -i "s/^JH_ZITADEL_CLIENT_SECRET=.*/JH_ZITADEL_CLIENT_SECRET=$JH_CLIENT_SECRET/" .env
    echo "✓ JupyterHub OIDC client: $JH_CLIENT_ID"
fi

echo ""
echo "=== Zitadel: создание OIDC клиента для Admin Dashboard ==="

DASH_CLIENT=$(curl -s --request POST "$ZITADEL_GRPC_HOST/management/v1/users/me/apps/oauth/client" \
  --header "Authorization: Bearer $ZITADEL_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"name\": \"admin-dashboard\",
    \"redirectUris\": [
      \"http://localhost:$DASHBOARD_PORT/callback\",
      \"http://admin-dashboard:5000/callback\"
    ],
    \"response_types\": [\"code\"],
    \"grant_types\": [\"authorization_code\", \"refresh_token\"],
    \"app_type\": \"web\",
    \"auth_method\": \"client_secret_basic\"
  }" 2>/dev/null)

DASH_CLIENT_ID=$(echo "$DASH_CLIENT" | jq -r '.clientId' 2>/dev/null || echo "placeholder")
DASH_CLIENT_SECRET=$(echo "$DASH_CLIENT" | jq -r '.clientSecret' 2>/dev/null || echo "placeholder")

if [[ "$DASH_CLIENT_ID" == "null" || -z "$DASH_CLIENT_ID" ]]; then
    DASH_CLIENT_ID="placeholder"
    DASH_CLIENT_SECRET="placeholder"
    echo "⚠ Не удалось создать Dashboard OIDC клиент через API"
else
    sed -i "s/^DASH_CLIENT_ID=.*/DASH_CLIENT_ID=$DASH_CLIENT_ID/" .env
    sed -i "s/^DASH_CLIENT_SECRET=.*/DASH_CLIENT_SECRET=$DASH_CLIENT_SECRET/" .env
    echo "✓ Admin Dashboard OIDC client: $DASH_CLIENT_ID"
fi

echo ""
echo "=== Zitadel: создание OIDC клиента для Nextcloud ==="

NC_CLIENT=$(curl -s --request POST "$ZITADEL_GRPC_HOST/management/v1/users/me/apps/oauth/client" \
  --header "Authorization: Bearer $ZITADEL_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"name\": \"nextcloud\",
    \"redirectUris\": [
      \"http://localhost:$NEXTCLOUD_PORT/apps/oidc_login/callback\",
      \"http://nextcloud:80/apps/oidc_login/callback\"
    ],
    \"response_types\": [\"code\"],
    \"grant_types\": [\"authorization_code\"],
    \"app_type\": \"web\",
    \"auth_method\": \"client_secret_basic\"
  }" 2>/dev/null)

NC_CLIENT_ID=$(echo "$NC_CLIENT" | jq -r '.clientId' 2>/dev/null || echo "placeholder")
NC_CLIENT_SECRET=$(echo "$NC_CLIENT" | jq -r '.clientSecret' 2>/dev/null || echo "placeholder")

if [[ "$NC_CLIENT_ID" == "null" || -z "$NC_CLIENT_ID" ]]; then
    NC_CLIENT_ID="placeholder"
    NC_CLIENT_SECRET="placeholder"
    echo "⚠ Не удалось создать Nextcloud OIDC клиент через API"
else
    echo "✓ Nextcloud OIDC client: $NC_CLIENT_ID"
fi

echo ""
echo "=== Zitadel: создание OIDC клиента для GitLab ==="

GL_CLIENT=$(curl -s --request POST "$ZITADEL_GRPC_HOST/management/v1/users/me/apps/oauth/client" \
  --header "Authorization: Bearer $ZITADEL_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"name\": \"gitlab\",
    \"redirectUris\": [
      \"http://localhost/oauth/callback\",
      \"http://gitlab:80/oauth/callback\"
    ],
    \"response_types\": [\"code\"],
    \"grant_types\": [\"authorization_code\"],
    \"app_type\": \"web\",
    \"auth_method\": \"client_secret_basic\"
  }" 2>/dev/null)

GL_CLIENT_ID=$(echo "$GL_CLIENT" | jq -r '.clientId' 2>/dev/null || echo "placeholder")
GL_CLIENT_SECRET=$(echo "$GL_CLIENT" | jq -r '.clientSecret' 2>/dev/null || echo "placeholder")

if [[ "$GL_CLIENT_ID" == "null" || -z "$GL_CLIENT_ID" ]]; then
    GL_CLIENT_ID="placeholder"
    GL_CLIENT_SECRET="placeholder"
    echo "⚠ Не удалось создать GitLab OIDC клиент через API"
else
    echo "✓ GitLab OIDC client: $GL_CLIENT_ID"
fi

echo ""
echo "=== Zitadel: сохранение issuer URL ==="

ZITADEL_ISSUER="http://zitadel:9200"
echo "Issuer URL: $ZITADEL_ISSUER"

echo ""
echo "=== Zitadel инициализация завершена ==="
echo "OIDC клиенты:"
echo "  JupyterHub:       $JH_CLIENT_ID"
echo "  Admin Dashboard:  $DASH_CLIENT_ID"
echo "  Nextcloud:        $NC_CLIENT_ID"
echo "  GitLab:           $GL_CLIENT_ID"
