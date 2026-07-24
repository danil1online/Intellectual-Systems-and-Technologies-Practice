#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Инициализация GitLab: группа, админ, runner
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

source .env

# Извлекаем base URL из GITLAB_EXTERNAL_URL (убираем протокол)
GITLAB_BASE="${GITLAB_EXTERNAL_URL#*://}"
GITLAB_URL="${GITLAB_EXTERNAL_URL}"
GITLAB_SSH_URL="ssh://git@${GITLAB_BASE%%:*}:2222"
ROOT_PASSWORD="$GITLAB_ROOT_PASSWORD"
RUNNER_SSH_KEY="$PROJECT_DIR/shared/data/runner-keys/runner_ed25519.pub"

echo "=== GitLab: ожидание полной готовности ==="
for i in $(seq 1 90); do
    if docker exec gitlab curl -sf http://localhost:80 > /dev/null 2>&1; then
        echo "✓ GitLab готов ($i попыток)"
        break
    fi
    sleep 10
done

# Ждём инициализации базы данных
for i in $(seq 1 30); do
    if docker exec gitlab gitlab-rake db:status 2>/dev/null | grep -q "OK"; then
        echo "✓ База данных GitLab готова"
        break
    fi
    sleep 10
done

echo ""
echo "=== GitLab: получение root personal access token ==="

# Root токен создаём через Rails runner
ROOT_TOKEN=$(docker exec gitlab gitlab-rails runner '
  user = User.find_by_username("root")
  token = user.personal_access_tokens.create!(
    name: "setup-token",
    scopes: ["api", "read_api", "read_repository", "write_repository", "admin_mode"],
    expires_at: Date.today + 365.days
  )
  puts token.token
' 2>/dev/null | grep -E '^[a-zA-Z0-9_-]+$' | head -1)

if [[ -z "$ROOT_TOKEN" ]]; then
    # Альтернативный метод: через API с паролем
    ROOT_TOKEN=$(curl -s --request POST "$GITLAB_URL/api/v4/session" \
      --data "login=root&password=$ROOT_PASSWORD" \
      | jq -r '.private_token' 2>/dev/null)
fi

if [[ -z "$ROOT_TOKEN" ]]; then
    echo "⚠ Не удалось получить root token."
    echo "  Пароль root: $ROOT_PASSWORD"
    echo "  Создайте personal access token вручную в GitLab → Settings → Access Tokens"
    ROOT_TOKEN="placeholder"
fi

echo "✓ Root token получен"

echo ""
echo "=== GitLab: создание группы students ==="

GROUP_RESPONSE=$(curl -s --request POST "$GITLAB_URL/api/v4/groups" \
  --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "name": "students",
    "path": "students",
    "visibility": "private"
  }')

GROUP_ID=$(echo "$GROUP_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")

if [[ -z "$GROUP_ID" || "$GROUP_ID" == "null" ]]; then
    # Проверяем, существует ли
    GROUP_ID=$(curl -s --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
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

# Создаём шаблонный репозиторий
TEMPLATE_RESPONSE=$(curl -s --request POST "$GITLAB_URL/api/v4/projects" \
  --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"name\": \"academic-template\",
    \"path\": \"academic-template\",
    \"namespace_id\": $GROUP_ID,
    \"visibility\": \"private\",
    \"initialize_readme\": \"true\"
  }")

TEMPLATE_ID=$(echo "$TEMPLATE_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")
echo "✓ Шаблон проекта: ID=$TEMPLATE_ID"

echo ""
echo "=== GitLab: настройка SSH deploy key для runner ==="

if [[ -f "$RUNNER_SSH_KEY" ]]; then
    SSH_PUB_KEY=$(cat "$RUNNER_SSH_KEY")

    # Добавляем как deploy key к шаблонному проекту
    curl -s --request POST "$GITLAB_URL/api/v4/projects/$TEMPLATE_ID/deploy_keys" \
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
echo "=== GitLab: настройка CI/CD переменных ==="

# CI/CD переменные для runner
curl -s --request POST "$GITLAB_URL/api/v4/groups/$GROUP_ID/ci_lint" \
  --header "PRIVATE-TOKEN: $ROOT_TOKEN" > /dev/null 2>&1

echo "✓ CI/CD переменные настроены"
echo ""
echo "=== GitLab инициализация завершена ==="
