#!/bin/bash
# Скрипт для инициализации Keycloak после старта контейнера
# Запускается: docker exec -it keycloak /opt/keycloak/bin/kcadm.sh exec /tmp/init_keycloak.sh

set -e

# Получаем admin token
ADMIN_TOKEN=$(/opt/keycloak/bin/kcadm.sh config credentials --server http://keycloak:9200/auth --realm master --user admin --password "$KC_ADMIN_PASSWORD" 2>/dev/null | grep -o '"accessToken":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ADMIN_TOKEN" ]; then
  echo "Failed to get admin token"
  exit 1
fi

echo "Admin token obtained"

# Upsert client function
upsert_client() {
  local CLIENT_ID=$1
  local SECRET=$2
  local REDIRECT1=$3
  local REDIRECT2=$4

  local INTERNAL_ID=$(curl -s "http://keycloak:9200/auth/admin/realms/istp/clients" \
    -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | \
    jq -r ".[] | select(.clientId==\"$CLIENT_ID\") | .id" 2>/dev/null)

  if [ -n "$INTERNAL_ID" ] && [ "$INTERNAL_ID" != "null" ]; then
    echo "Client $CLIENT_ID exists. Updating..."
    curl -s -X PUT "http://keycloak:9200/auth/admin/realms/istp/clients/$INTERNAL_ID" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"clientId\": \"$CLIENT_ID\",
        \"secret\": \"$SECRET\",
        \"redirectUris\": [\"$REDIRECT1\", \"$REDIRECT2\"],
        \"webOrigins\": [\"+\"],
        \"enabled\": true,
        \"protocol\": \"openid-connect\",
        \"standardFlowEnabled\": true,
        \"publicClient\": false,
        \"frontchannelLogout\": true,
        \"consentRequired\": false
      }" > /dev/null
  else
    echo "Client $CLIENT_ID not found. Creating..."
    local NEW_ID=$(curl -s -X POST "http://keycloak:9200/auth/admin/realms/istp/clients" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"clientId\": \"$CLIENT_ID\",
        \"secret\": \"$SECRET\",
        \"redirectUris\": [\"$REDIRECT1\", \"$REDIRECT2\"],
        \"webOrigins\": [\"+\"],
        \"enabled\": true,
        \"protocol\": \"openid-connect\",
        \"standardFlowEnabled\": true,
        \"publicClient\": false,
        \"frontchannelLogout\": true,
        \"consentRequired\": false
      }" | jq -r '.id' 2>/dev/null)
    echo "Client $CLIENT_ID created (ID: $NEW_ID)"
  fi
}

# Create pre-created lecturer accounts
create_user() {
  local username="$1"
  local email="$2"
  local password="$3"

  local USER_ID=$(curl -s "http://keycloak:9200/auth/admin/realms/istp/users?username=$username" \
    -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | \
    jq -r ".[0].id" 2>/dev/null)

  if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
    USER_ID=$(curl -s -X POST "http://keycloak:9200/auth/admin/realms/istp/users" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"username\": \"$username\",
        \"email\": \"$email\",
        \"enabled\": true,
        \"emailVerified\": true,
        \"firstName\": \"$username\",
        \"lastName\": \"lecturer\"
      }" | jq -r '.id' 2>/dev/null)

    if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
      curl -s -X PUT "http://keycloak:9200/auth/admin/realms/istp/users/$USER_ID/reset-password" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"type\":\"password\",\"value\":\"$password\",\"temporary\":false}" > /dev/null 2>&1
      echo "Created lecturer: $username / $email"
    fi
  else
    echo "User $username already exists"
  fi
}

# Create OIDC clients
upsert_client "jupyterhub" "$OIDC_JUPYTER_SECRET" "http://${HOST_IP}:8000/hub/oauth_callback" "http://${HOST_IP_LOCAL}:8000/hub/oauth_callback"
upsert_client "gitlab" "$OIDC_GITLAB_SECRET" "http://${HOST_IP}/users/auth/openid_connect/callback" "http://${HOST_IP_LOCAL}/users/auth/openid_connect/callback"
upsert_client "nextcloud" "$OIDC_NEXTCLOUD_SECRET" "http://${HOST_IP}:8080/*" "http://${HOST_IP_LOCAL}:8080/*"
upsert_client "admin-dashboard" "$OIDC_DASHBOARD_SECRET" "http://${HOST_IP}:$DASHBOARD_PORT/*" "http://${HOST_IP_LOCAL}:$DASHBOARD_PORT/*"
upsert_client "registry" "$OIDC_REGISTRY_SECRET" "http://${HOST_IP}:5050/*" "http://${HOST_IP_LOCAL}:5050/*"

# Update gitlab redirectUris to include all possible hosts
GITLAB_CLIENT_ID=$(curl -s "http://keycloak:9200/auth/admin/realms/istp/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | \
  jq -r ".[] | select(.clientId==\"gitlab\") | .id" 2>/dev/null)
if [ -n "$GITLAB_CLIENT_ID" ] && [ "$GITLAB_CLIENT_ID" != "null" ]; then
  /opt/keycloak/bin/kcadm.sh update clients/$GITLAB_CLIENT_ID -r istp \
    -s "redirectUris=['http://${HOST_IP}/users/auth/openid_connect/callback','http://${HOST_IP_LOCAL}/users/auth/openid_connect/callback','http://192.168.1.38/users/auth/openid_connect/callback']" 2>/dev/null || true
fi

# Create lecturer accounts
create_user "lecturer_01" "lecturer01@istp.local" "$KC_LECTURER_01_PASSWORD"
create_user "lecturer_02" "lecturer02@istp.local" "$KC_LECTURER_02_PASSWORD"

echo "Keycloak initialization completed successfully!"
