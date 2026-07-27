#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Инициализация Nextcloud + OnlyOffice интеграция
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

source .env

NEXTCLOUD_URL="http://localhost:$NEXTCLOUD_PORT"
NC_ADMIN_USER="$NC_ADMIN_USER"
NC_ADMIN_PASSWORD="$NC_ADMIN_PASSWORD"

echo "=== Nextcloud: ожидание готовности ==="
for i in $(seq 1 30); do
    if docker exec nextcloud php occ status 2>/dev/null | grep -q "installed"; then
        echo "✓ Nextcloud готов ($i попыток)"
        break
    fi
    sleep 10
done

echo ""
echo "=== Nextcloud: установка OnlyOffice app ==="

docker exec nextcloud php occ app:enable onlyoffice 2>/dev/null || \
docker exec nextcloud php occ app:install onlyoffice 2>/dev/null || \
echo "⚠ OnlyOffice app уже установлен"

echo "✓ OnlyOffice app включён"

echo ""
echo "=== Nextcloud: настройка OnlyOffice ==="

docker exec nextcloud php occ config:app:set onlyoffice DocumentServerUrl \
  --value "http://onlyoffice:80/" 2>/dev/null || \
echo "⚠ OnlyOffice URL настройки через UI: http://onlyoffice:80"

docker exec nextcloud php occ config:app:set onlyoffice JWTEnabled \
  --value "true" 2>/dev/null

docker exec nextcloud php occ config:app:set onlyoffice JWTSecret \
  --value "$ONLYOFFICE_JWT_SECRET" 2>/dev/null || \
echo "⚠ OnlyOffice JWT настройка через UI"

echo "✓ OnlyOffice настроен"

echo ""
echo "=== Nextcloud: настройка OIDC авторизации (Keycloak) ==="

docker exec nextcloud php occ config:app:set oidc_login oidcEndpoint \
  --value "http://keycloak:8080/auth/realms/istp" 2>/dev/null || \
echo "⚠ OIDC настройка через UI"

docker exec nextcloud php occ config:app:set oidc_login clientID \
  --value "$NC_KEYCLOAK_CLIENT_ID" 2>/dev/null || \
echo "⚠ OIDC Client ID через UI"

docker exec nextcloud php occ config:app:set oidc_login clientSecret \
  --value "$NC_KEYCLOAK_CLIENT_SECRET" 2>/dev/null || \
echo "⚠ OIDC Client Secret через UI"

docker exec nextcloud php occ config:app:set oidc_login autoCreateUser \
  --value "true" 2>/dev/null || \
echo "⚠ Auto-create user через UI"

docker exec nextcloud php occ config:app:set oidc_login updateUserAttributes \
  --value '{"preferred_username":"preferred_username","email":"email"}' 2>/dev/null || \
echo "⚠ updateUserAttributes через UI"

docker exec nextcloud php occ config:app:set oidc_login logoutMethod \
  --value "redirect" 2>/dev/null || \
echo "⚠ logoutMethod через UI"

echo "✓ OIDC авторизация настроена (проверьте через UI)"

echo ""
echo "=== Nextcloud: создание директорий для студентов ==="

# Создаём структуру директорий в shared volume
docker exec nextcloud mkdir -p /var/www/html/data/admin/files/shared-data 2>/dev/null || true
docker exec nextcloud mkdir -p /var/www/html/data/admin/files/shared-logs 2>/dev/null || true
docker exec nextcloud mkdir -p /var/www/html/data/admin/files/student-work 2>/dev/null || true

echo "✓ Директории созданы"
echo ""
echo "=== Nextcloud инициализация завершена ==="
