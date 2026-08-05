#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Инициализация GitLab: группа, админ, runner
# ВАЖНО: OIDC настроен через GITLAB_OMNIBUS_CONFIG в docker-compose
# Этот скрипт занимается ТОЛЬКО API-запросами
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

source .env

GITLAB_BASE="${GITLAB_EXTERNAL_URL#*://}"
GITLAB_URL="http://localhost"
GITLAB_SSH_URL="ssh://git@${GITLAB_BASE%%:*}:2222"
ROOT_PASSWORD="$GITLAB_ROOT_PASSWORD"
RUNNER_SSH_KEY="$SCRIPT_DIR/shared/data/runner-keys/runner_ed25519.pub"

echo "=== GitLab: ожидание полной готовности ==="
for i in $(seq 1 90); do
    if docker exec gitlab curl -sf http://localhost:80 > /dev/null 2>&1; then
        echo "✓ GitLab готов ($i попыток)"
        break
    fi
    sleep 10
done

echo ""
echo "=== GitLab: получение root personal access token ==="

ROOT_TOKEN=$(timeout 60 docker exec gitlab gitlab-rails runner '
  user = User.find_by_username("root")
  token = user.personal_access_tokens.where(name: "setup-token").first
  if token
    puts token.token
  else
    token = user.personal_access_tokens.create!(
      name: "setup-token",
      scopes: ["api", "read_api", "read_repository", "write_repository", "admin_mode"],
      expires_at: Date.today + 365.days
    )
    puts token.token
  end
' 2>&1 | tr -d '[:space:]')

if [[ -z "$ROOT_TOKEN" ]]; then
    echo "⚠ Не удалось получить root token."
    ROOT_TOKEN="placeholder"
fi

echo "✓ Root token получен"

echo ""
echo "=== GitLab: создание группы students ==="

GROUP_RESPONSE=$(curl -s --max-time 30 --request POST "$GITLAB_URL/api/v4/groups" \
  --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "name": "students",
    "path": "students",
    "visibility": "public"
  }')

GROUP_ID=$(echo "$GROUP_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")

if [[ -z "$GROUP_ID" || "$GROUP_ID" == "null" ]]; then
    GROUP_ID=$(curl -s --max-time 30 --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
      "$GITLAB_URL/api/v4/groups?search=students" \
      | jq -r '.[0].id' 2>/dev/null)
fi

if [[ -z "$GROUP_ID" ]]; then
    GROUP_ID=1
    echo "⚠ Группа создана вручную или уже существует"
else
    echo "✓ Группа students создана (ID: $GROUP_ID)"
fi

echo ""
echo "=== GitLab: создание шаблона проекта для студентов ==="

TEMPLATE_RESPONSE=$(curl -s --max-time 30 --request POST "$GITLAB_URL/api/v4/projects" \
  --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"name\": \"project\",
    \"path\": \"project\",
    \"namespace_id\": $GROUP_ID,
    \"visibility\": \"public\"
  }")

TEMPLATE_ID=$(echo "$TEMPLATE_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")
echo "✓ Шаблон проекта: ID=$TEMPLATE_ID"

echo ""
echo "=== GitLab: настройка SSH deploy key для runner ==="

if [[ -f "$RUNNER_SSH_KEY" ]]; then
    SSH_PUB_KEY=$(cat "$RUNNER_SSH_KEY")

    curl -s --max-time 30 --request POST "$GITLAB_URL/api/v4/projects/$TEMPLATE_ID/deploy_keys" \
      --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
      --header "Content-Type: application/json" \
      --data "{
        \"title\": \"gitlab-runner\",
        \"key\": \"$SSH_PUB_KEY\"
      }" > /dev/null 2>&1

    echo "✓ SSH deploy key добавлена для runner"
else
    echo "⚠ SSH ключ runner не найден: $RUNNER_SSH_KEY"
fi

echo ""
echo "=== GitLab: создание локальных учётных записей лекторов ==="

# Создаём локальных пользователей-лекторов
# Они нужны для входа по паролю (OIDC auto-link работает для студентов)
for LECT_NUM in 01 02; do
    LECT_USER="lecturer_${LECT_NUM}"
    LECT_PASS_VAR="LECTURER_${LECT_NUM}_PASSWORD"
    LECT_PASS="${!LECT_PASS_VAR}"
    
    # Проверяем существование
    EXISTING=$(curl -s --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
      "$GITLAB_URL/api/v4/users?username=$LECT_USER" 2>/dev/null)
    
    USER_ID=$(echo "$EXISTING" | jq -r '.[0].id' 2>/dev/null || echo "")
    
    if [[ -z "$USER_ID" || "$USER_ID" == "null" ]]; then
        # Создаём пользователя
        CREATE_RESP=$(curl -s --max-time 30 --request POST "$GITLAB_URL/api/v4/users" \
          --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
          --header "Content-Type: application/json" \
          --data "{
            \"name\": \"Lecturer $LECT_NUM\",
            \"username\": \"$LECT_USER\",
            \"email\": \"lecturer${LECT_NUM}@istp.local\",
            \"password\": \"$LECT_PASS\",
            \"skip_confirmation\": true
          }")
        
        NEW_ID=$(echo "$CREATE_RESP" | jq -r '.id' 2>/dev/null || echo "")
        if [[ -n "$NEW_ID" && "$NEW_ID" != "null" ]]; then
            echo "✓ Лектор $LECT_USER создан"
        else
            echo "⚠ Не удалось создать лектора $LECT_USER: $CREATE_RESP"
        fi
    else
        echo "✓ Лектор $LECT_USER уже существует"
    fi
done

echo ""
echo "=== GitLab инициализация завершена ==="
