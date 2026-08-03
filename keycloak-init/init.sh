#!/bin/bash
# ============================================
# Keycloak initializer: realm, clients, users
# ============================================

echo "=== Keycloak Init: waiting for API ==="

KEYCLOAK_URL="http://keycloak:9200/auth"
MAX_WAIT=120
WAIT_COUNT=0

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  # Проверяем что Keycloak отвечает (даже 401 означает что он работает)
  if curl -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/admin/realms/master" 2>/dev/null | grep -qE '^(200|401|403)$'; then
    echo "Keycloak API is ready after ${WAIT_COUNT} seconds"
    break
  fi
  sleep 5
  WAIT_COUNT=$((WAIT_COUNT + 5))
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
  echo "ERROR: Keycloak API not ready after ${MAX_WAIT} seconds"
  exit 1
fi

# Получаем токен админа через admin-cli (password grant)
echo "Authenticating as admin..."
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=$KC_ADMIN_PASSWORD")

ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$ADMIN_TOKEN" ]; then
  echo "ERROR: Cannot authenticate as admin"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "Admin authenticated successfully"

if [ -z "$ADMIN_TOKEN" ]; then
  echo "ERROR: Cannot authenticate as admin"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "Admin authenticated successfully"

# Создаём realm istp
echo "Creating realm istp..."
REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/admin/realms/istp" \
  -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null)

if [ "$REALM_EXISTS" != "200" ]; then
  curl -s -X POST "$KEYCLOAK_URL/admin/realms" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "realm": "istp",
      "enabled": true,
      "registrationAllowed": true,
      "registrationEmailAsUsername": false,
      "editUsernameAllowed": true,
      "verifyEmail": false,
      "loginTheme": "keycloak",
      "accountTheme": "keycloak",
      "attributes": {
        "cibaBackchannelTokenDeliveryMode": "poll",
        "cibaExpiresIn": "120",
        "cibaAuthRequestedUserHint": "login_hint",
        "parRequestUriLifespan": "60",
        "cibaInterval": "5",
        "realmReusableOtpCode": "false",
        "frontendUrl": "http://${GITLAB_HOST}:${KEYCLOAK_PORT:-9200}/auth"
      }
    }' > /dev/null
  echo "Realm istp created"
else
  echo "Realm istp already exists"
  # Обновляем frontendUrl для существующего realm
  curl -s -X PUT "$KEYCLOAK_URL/admin/realms/istp" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"attributes\":{\"frontendUrl\":\"http://${GITLAB_HOST}:${KEYCLOAK_PORT:-9200}/auth\"}}" > /dev/null
  echo "  Realm frontendUrl updated"
fi

# Функция создания/обновления клиента
upsert_client() {
  local CLIENT_ID=$1
  local SECRET=$2
  local REDIRECT1=$3
  local REDIRECT2=$4

  echo "Processing client: $CLIENT_ID"

  # Проверяем существование
  CLIENT_JSON=$(curl -s "$KEYCLOAK_URL/admin/realms/istp/clients" \
    -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null)
  
  INTERNAL_ID=$(echo "$CLIENT_JSON" | jq -r ".[] | select(.clientId==\"$CLIENT_ID\") | .id" 2>/dev/null)

  # Формируем JSON клиента
  CLIENT_DATA=$(cat <<CLIEOF
{
  "clientId": "$CLIENT_ID",
  "secret": "$SECRET",
  "redirectUris": ["$REDIRECT1", "$REDIRECT2"],
  "webOrigins": ["+"],
  "enabled": true,
  "protocol": "openid-connect",
  "standardFlowEnabled": true,
  "publicClient": false,
  "frontchannelLogout": true,
  "consentRequired": false,
  "attributes": {
    "oidc.ciba.grant.enabled": "false",
    "oidc.backchannel.logout.sessions.enabled": "true",
    "oidc.backchannel.logout.revoke.offline.tokens": "false"
  }
}
CLIEOF
)

  if [ -n "$INTERNAL_ID" ] && [ "$INTERNAL_ID" != "null" ]; then
    # Обновляем существующий клиент
    curl -s -X PUT "$KEYCLOAK_URL/admin/realms/istp/clients/$INTERNAL_ID" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$CLIENT_DATA" > /dev/null
    echo "  Client $CLIENT_ID updated"
  else
    # Создаём нового клиента
    curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$CLIENT_DATA" > /dev/null
    echo "  Client $CLIENT_ID created"
  fi

  echo "  Client $CLIENT_ID processed with secret"
}

# Создаём клиентов
upsert_client "jupyterhub" "$OIDC_JUPYTER_SECRET" \
  "http://${GITLAB_HOST}:${JUPYTERHUB_PORT:-8000}/hub/oauth_callback" \
  "http://localhost:${JUPYTERHUB_PORT:-8000}/hub/oauth_callback"

upsert_client "gitlab" "$OIDC_GITLAB_SECRET" \
  "http://${GITLAB_HOST}/users/auth/openid_connect/callback" \
  "http://localhost/users/auth/openid_connect/callback"

upsert_client "nextcloud" "$OIDC_NEXTCLOUD_SECRET" \
  "http://${GITLAB_HOST}:${NEXTCLOUD_PORT:-8080}/*" \
  "http://localhost:${NEXTCLOUD_PORT:-8080}/*"

upsert_client "admin-dashboard" "$OIDC_DASHBOARD_SECRET" \
  "http://${GITLAB_HOST}:${DASHBOARD_PORT:-9000}/*" \
  "http://localhost:${DASHBOARD_PORT:-9000}/*"

upsert_client "registry" "$OIDC_REGISTRY_SECRET" \
  "http://${GITLAB_HOST}:5050/*" \
  "http://localhost:5050/*"

# Сохраняю все секреты в shared файл для других сервисов
mkdir -p /shared/oidc 2>/dev/null || true
cat > /shared/oidc/secrets.env <<SECEOF
jupyterhub_SECRET=$OIDC_JUPYTER_SECRET
nextcloud_SECRET=$OIDC_NEXTCLOUD_SECRET
gitlab_SECRET=$OIDC_GITLAB_SECRET
admin-dashboard_SECRET=$OIDC_DASHBOARD_SECRET
registry_SECRET=$OIDC_REGISTRY_SECRET
SECEOF
echo "OIDC secrets saved to /shared/oidc/secrets.env"

# Настройка OIDC mappers для клиента gitlab
setup_gitlab_mappers() {
  echo "Setting up GitLab OIDC mappers..."
  
  GITLAB_CLIENT_ID=$(curl -s "$KEYCLOAK_URL/admin/realms/istp/clients" \
    -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | \
    jq -r ".[] | select(.clientId==\"gitlab\") | .id" 2>/dev/null)
  
  if [ -z "$GITLAB_CLIENT_ID" ] || [ "$GITLAB_CLIENT_ID" = "null" ]; then
    echo "  GitLab client not found, skipping mappers"
    return
  fi
  
  # Удаляем старые mappers
  curl -s "$KEYCLOAK_URL/admin/realms/istp/clients/$GITLAB_CLIENT_ID/scopes" \
    -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | \
    jq -r '.[].id' 2>/dev/null | while read scope_id; do
      curl -s -X DELETE "$KEYCLOAK_URL/admin/realms/istp/clients/$GITLAB_CLIENT_ID/scopes/mappings" \
        -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null 2>&1 || true
    done
  
  # Создаем mapper: preferred_username -> name
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients/$GITLAB_CLIENT_ID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "preferred_username",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "preferred_username",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "name",
        "jsonType.label": "String"
      }
    }' > /dev/null
  echo "  Mapper 'preferred_username -> name' created/updated"
  
  # Создаем mapper: email -> email
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients/$GITLAB_CLIENT_ID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "email",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "email",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "email",
        "jsonType.label": "String"
      }
    }' > /dev/null
  echo "  Mapper 'email -> email' created/updated"
  
  # Создаем mapper: given_name -> first_name
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients/$GITLAB_CLIENT_ID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "given_name",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "givenName",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "first_name",
        "jsonType.label": "String"
      }
    }' > /dev/null
  echo "  Mapper 'given_name -> first_name' created/updated"
  
  # Создаем mapper: family_name -> last_name
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients/$GITLAB_CLIENT_ID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "family_name",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "lastName",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "last_name",
        "jsonType.label": "String"
      }
    }' > /dev/null
  echo "  Mapper 'family_name -> last_name' created/updated"
  
  # Создаем mapper: nameidentifier (subject) -> uid
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients/$GITLAB_CLIENT_ID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "subject",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "username",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "uid",
        "jsonType.label": "String"
      }
    }' > /dev/null
  echo "  Mapper 'subject -> uid' created/updated"
  
  # Включаем все mappers
  curl -s "$KEYCLOAK_URL/admin/realms/istp/clients/$GITLAB_CLIENT_ID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | \
    jq -r '.[].id' 2>/dev/null | while read mapper_id; do
      curl -s -X PUT "$KEYCLOAK_URL/admin/realms/istp/clients/$GITLAB_CLIENT_ID/protocol-mappers/models/$mapper_id" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"config":{"userinfo.token.claim":["true"],"user.attribute":[""],"id.token.claim":["true"],"access.token.claim":["true"],"claim.name":[""],"jsonType.label":["String"]}}' > /dev/null 2>&1 || true
    done
  
  echo "  GitLab mappers configured successfully"
}

# Настройка OIDC mappers для клиентов
setup_oidc_mappers() {
  local CLIENT_ID=$1

  echo "Setting up OIDC mappers for: $CLIENT_ID"

  local OIDC_INTERNAL_ID=$(curl -s "$KEYCLOAK_URL/admin/realms/istp/clients" \
    -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | \
    jq -r ".[] | select(.clientId==\"$CLIENT_ID\") | .id" 2>/dev/null)

  if [ -z "$OIDC_INTERNAL_ID" ] || [ "$OIDC_INTERNAL_ID" = "null" ]; then
    echo "  Client $CLIENT_ID not found, skipping mappers"
    return
  fi

  # Создаем mapper: preferred_username
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients/$OIDC_INTERNAL_ID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "preferred_username",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "preferred_username",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "preferred_username",
        "jsonType.label": "String"
      }
    }' > /dev/null
  echo "  Mapper 'preferred_username' created/updated"

  # Создаем mapper: email
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients/$OIDC_INTERNAL_ID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "email",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "email",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "email",
        "jsonType.label": "String"
      }
    }' > /dev/null
  echo "  Mapper 'email' created/updated"

  # Создаем mapper: given_name
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients/$OIDC_INTERNAL_ID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "given_name",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "givenName",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "given_name",
        "jsonType.label": "String"
      }
    }' > /dev/null
  echo "  Mapper 'given_name' created/updated"

  # Создаем mapper: family_name
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/istp/clients/$OIDC_INTERNAL_ID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "family_name",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "lastName",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "family_name",
        "jsonType.label": "String"
      }
    }' > /dev/null
  echo "  Mapper 'family_name' created/updated"

  # Включаем все mappers
  curl -s "$KEYCLOAK_URL/admin/realms/istp/clients/$OIDC_INTERNAL_ID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | \
    jq -r '.[].id' 2>/dev/null | while read mapper_id; do
      curl -s -X PUT "$KEYCLOAK_URL/admin/realms/istp/clients/$OIDC_INTERNAL_ID/protocol-mappers/models/$mapper_id" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"config":{"userinfo.token.claim":["true"],"user.attribute":[""],"id.token.claim":["true"],"access.token.claim":["true"],"claim.name":[""],"jsonType.label":["String"]}}' > /dev/null 2>&1 || true
    done

  echo "  OIDC mappers for $CLIENT_ID configured successfully"
}

setup_oidc_mappers "jupyterhub"
setup_oidc_mappers "nextcloud"
setup_oidc_mappers "admin-dashboard"
setup_oidc_mappers "registry"
setup_gitlab_mappers

# Создаём пользователей-лекторов
create_user() {
  local USERNAME=$1
  local EMAIL=$2
  local PASSWORD=$3

  echo "Processing user: $USERNAME"

  # Проверяем существование
  USER_JSON=$(curl -s "$KEYCLOAK_URL/admin/realms/istp/users?username=$USERNAME" \
    -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null)
  
  USER_ID=$(echo "$USER_JSON" | jq -r '.[0].id // empty' 2>/dev/null || echo "")

  if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
    # Создаём пользователя
    CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/istp/users" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"username\": \"$USERNAME\",
        \"email\": \"$EMAIL\",
        \"enabled\": true,
        \"emailVerified\": true,
        \"firstName\": \"$USERNAME\",
        \"lastName\": \"lecturer\"
      }")
    
    HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -1)
    BODY=$(echo "$CREATE_RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
      # Извлекаем ID из Location header
      LOCATION=$(curl -s -I -X POST "$KEYCLOAK_URL/admin/realms/istp/users" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
          \"username\": \"$USERNAME\",
          \"email\": \"$EMAIL\",
          \"enabled\": true,
          \"emailVerified\": true,
          \"firstName\": \"$USERNAME\",
          \"lastName\": \"lecturer\"
        }" 2>/dev/null | grep -i location | tr -d '\r' | awk '{print $2}' | sed 's|.*/||')
      
      if [ -n "$LOCATION" ] && echo "$LOCATION" | grep -qE '^[0-9a-f-]{36}$'; then
        USER_ID="$LOCATION"
      fi
      
      if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
        # Устанавливаем пароль
        curl -s -X PUT "$KEYCLOAK_URL/admin/realms/istp/users/$USER_ID/reset-password" \
          -H "Authorization: Bearer $ADMIN_TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"type\":\"password\",\"value\":\"$PASSWORD\",\"temporary\":false}" > /dev/null 2>&1
        echo "  User $USERNAME created with email $EMAIL"
      else
        echo "  WARNING: Could not get user ID for $USERNAME"
      fi
    else
      echo "  WARNING: Failed to create user $USERNAME (HTTP $HTTP_CODE)"
    fi
  else
    # Пользователь существует — устанавливаем пароль
    curl -s -X PUT "$KEYCLOAK_URL/admin/realms/istp/users/$USER_ID/reset-password" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"type\":\"password\",\"value\":\"$PASSWORD\",\"temporary\":false}" > /dev/null 2>&1
    echo "  User $USERNAME already exists, password reset"
  fi
}

# Создаём лекторов с username lecturer_01 и lecturer_02
create_user "lecturer_01" "lecturer01@istp.local" "$KC_LECTURER_01_PASSWORD"
create_user "lecturer_02" "lecturer02@istp.local" "$KC_LECTURER_02_PASSWORD"

echo ""
echo "=== Keycloak Init completed ==="
echo "Realm: istp"
echo "Clients: jupyterhub, gitlab, nextcloud, admin-dashboard, registry"
echo "Users: lecturer01@istp.local, lecturer02@istp.local"
