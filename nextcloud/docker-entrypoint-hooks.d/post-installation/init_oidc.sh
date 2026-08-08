#!/bin/bash
# ============================================
# Hook для Nextcloud: настройка OIDC Login плагина
# Выполняется после установки Nextcloud
# ============================================

set -e

echo "=== Nextcloud: ожидание полной готовности ==="

WAIT_COUNT=0
MAX_WAIT=180
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  if php /var/www/html/occ status --no-warnings 2>/dev/null | grep -q "installed: true"; then
    echo "✓ Nextcloud готов после ${WAIT_COUNT} секунд"
    break
  fi
  sleep 5
  WAIT_COUNT=$((WAIT_COUNT + 5))
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
  echo "ERROR: Nextcloud не запустился за отведённое время"
  exit 1
fi

echo "=== Nextcloud: активация и настройка OIDC Login ==="

# Включаем oidc_login плагин
php /var/www/html/occ app:enable oidc_login 2>/dev/null || true

# Получаю секрет: сначала из shared файла (от keycloak-init), потом из env
if [ -f /shared/oidc/secrets.env ]; then
  NC_SECRET_FROM_KC=$(grep "nextcloud_SECRET=" /shared/oidc/secrets.env 2>/dev/null | cut -d= -f2)
  if [ -n "$NC_SECRET_FROM_KC" ]; then
    echo "Using secret from Keycloak init: /shared/oidc/secrets.env"
    OIDC_NEXTCLOUD_SECRET="$NC_SECRET_FROM_KC"
  fi
fi

# Настраиваем OIDC параметры
php /var/www/html/occ config:system:set oidc_login_provider_url --value="http://keycloak:9200/auth/realms/istp" 2>/dev/null || true
php /var/www/html/occ config:system:set oidc_login_well_known_url --value="http://keycloak:9200/auth/realms/istp/.well-known/openid-configuration" 2>/dev/null || true
php /var/www/html/occ config:system:set oidc_login_client_id --value="nextcloud" 2>/dev/null || true
php /var/www/html/occ config:system:set oidc_login_client_secret --value="${OIDC_NEXTCLOUD_SECRET}" 2>/dev/null || true
php /var/www/html/occ config:system:set oidc_login_button_text --value="Войти через Keycloak" 2>/dev/null || true
php /var/www/html/occ config:system:set oidc_login_auto_redirect --value="false" --type=boolean 2>/dev/null || true
php /var/www/html/occ config:system:set oidc_login_disable_registration --value="false" --type=boolean 2>/dev/null || true
php /var/www/html/occ config:system:set oidc_login_auto_create_users --value="true" --type=boolean 2>/dev/null || true
php /var/www/html/occ config:system:set oidc_login_id_attribute --value="preferred_username" 2>/dev/null || true

echo "✓ OIDC Login настроен для Nextcloud."

echo "=== Nextcloud: настройка trusted_domains ==="

# Добавляем домены в trusted_domains
php /var/www/html/occ config:system:set trusted_domains 1 --value="$HOST_IP:$NEXTCLOUD_PORT" 2>/dev/null || true
php /var/www/html/occ config:system:set trusted_domains 2 --value="localhost:$NEXTCLOUD_PORT" 2>/dev/null || true
php /var/www/html/occ config:system:set trusted_domains 3 --value="$LOCAL_IP:$NEXTCLOUD_PORT" 2>/dev/null || true

# Настраиваем overwrite параметры для корректной генерации URL
php /var/www/html/occ config:system:set overwritehost --value="$HOST_IP:$NEXTCLOUD_PORT" 2>/dev/null || true
php /var/www/html/occ config:system:set overwrite.cli.url --value="http://$HOST_IP:$NEXTCLOUD_PORT" 2>/dev/null || true
php /var/www/html/occ config:system:set overwriteprotocol --value="http" 2>/dev/null || true

echo "✓ Trusted domains настроены: $HOST_IP:$NEXTCLOUD_PORT, localhost:$NEXTCLOUD_PORT, $LOCAL_IP:$NEXTCLOUD_PORT"

echo "✓ Nextcloud полностью настроен"
