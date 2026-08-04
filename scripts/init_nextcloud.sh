#!/bin/bash
# ============================================
# Проверка настройки OIDC в Nextcloud
# OIDC настраивается автоматически хуком
# init_oidc.sh при старте контейнера.
# Этот скрипт только проверяет результат.
# ============================================

set -uo pipefail

# --- Функции вывода (дублируем setup.sh) ---
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_step() { echo -e "[\033[0;34m$(date '+%H:%M:%S')\033[0m] $1"; }

# --- Загрузка переменных из .env ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

ENV_FILE=""
if [ -f "$PROJECT_DIR/.env" ]; then
    ENV_FILE="$PROJECT_DIR/.env"
elif [ -f "./.env" ]; then
    ENV_FILE="./.env"
fi

if [ -n "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
    print_step "Загружены переменные из: $ENV_FILE"
fi

# Fallback: если HOST_IP не определён в .env, берём GITLAB_HOST
if [ -z "${HOST_IP:-}" ] && [ -n "${GITLAB_HOST:-}" ]; then
    HOST_IP="$GITLAB_HOST"
    print_step "HOST_IP взят из GITLAB_HOST: $HOST_IP"
fi

CONTAINER="nextcloud"
ERRORS=0

echo ""
echo "=== Nextcloud: проверка OIDC ==="

# Проверка, что контейнер работает
STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "not_found")
if [[ "$STATUS" != "running" ]]; then
    echo "✗ Контейнер $CONTAINER не запущен (статус: $STATUS)"
    exit 1
fi
echo "✓ Контейнер $CONTAINER запущен"

# Функция проверки OIDC-параметра
check_oidc() {
    local NAME="$1"
    local EXPECTED="$2"
    local ACTUAL

    ACTUAL=$(docker exec "$CONTAINER" php occ config:system:get "$NAME" 2>/dev/null)
    if [[ -z "$ACTUAL" ]]; then
        echo "✗ oidc_login: $NAME не настроен"
        ERRORS=$((ERRORS + 1))
        return
    fi
    if [[ "$ACTUAL" == "$EXPECTED" ]]; then
        echo "✓ oidc_login $NAME настроен"
    else
        echo "⚠ oidc_login $NAME: ожидалось '$EXPECTED', установлено '$ACTUAL'"
        ERRORS=$((ERRORS + 1))
    fi
}

# Функция проверки trusted_domains
check_trusted_domain() {
    local DOMAIN="$1"
    local ACTUAL

    ACTUAL=$(docker exec "$CONTAINER" php occ config:system:get trusted_domains 2>/dev/null | grep -q "$DOMAIN" && echo "$DOMAIN" || echo "")
    if [[ -z "$ACTUAL" ]]; then
        echo "✗ trusted_domains: '$DOMAIN' отсутствует"
        ERRORS=$((ERRORS + 1))
    else
        echo "✓ trusted_domains: '$DOMAIN' присутствует"
    fi
}

# Проверка основных OIDC-параметров
echo ""
echo "--- OIDC ---"
check_oidc "oidc_login_provider_url" "http://${HOST_IP}:${KEYCLOAK_PORT}/auth/realms/istp"
check_oidc "oidc_login_well_known_url" "http://${HOST_IP}:${KEYCLOAK_PORT}/auth/realms/istp/.well-known/openid-configuration"
check_oidc "oidc_login_client_id" "nextcloud"
check_oidc "oidc_login_auto_create_users" "true"
check_oidc "oidc_login_id_attribute" "preferred_username"
check_oidc "oidc_login_auto_redirect" "false"

# Проверка trusted_domains
echo ""
echo "--- trusted_domains ---"
check_trusted_domain "$HOST_IP:$NEXTCLOUD_PORT"
check_trusted_domain "localhost:$NEXTCLOUD_PORT"
check_trusted_domain "$LOCAL_IP:$NEXTCLOUD_PORT"

# Проверка overwrite
echo ""
echo "--- overwrite ---"
check_oidc "overwritehost" "$HOST_IP:$NEXTCLOUD_PORT"
check_oidc "overwrite.cli.url" "http://$HOST_IP:$NEXTCLOUD_PORT"
check_oidc "overwriteprotocol" "http"

# Финальный вывод
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo "✓ Nextcloud OIDC настроен корректно"
    exit 0
else
    echo "⚠ Обнаружено $ERRORS проблем(а) с настройкой OIDC"
    echo ""
    echo "  Если Nextcloud только запущен, подождите 1-2 минуты."
    echo "  Логи: docker logs $CONTAINER"
    exit 1
fi
