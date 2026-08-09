#!/bin/bash
# ============================================
# Keycloak Scheduled Logout
# Invalidation of all Keycloak sessions for realm 'istp'
# ============================================

set -e

KEYCLOAK_URL="http://keycloak:9200/auth"
REALM="istp"
LOGFILE="/var/log/scheduled-logout.log"

echo "[$(date)] ===== Keycloak logout started =====" >> "$LOGFILE"

# --- Get admin token (password grant via admin-cli) ---
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=$KC_ADMIN_PASSWORD" 2>/dev/null)

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")

if [ -z "$ACCESS_TOKEN" ]; then
  echo "[$(date)] ERROR: Failed to get admin token" >> "$LOGFILE"
  echo "[$(date)] Response: $TOKEN_RESPONSE" >> "$LOGFILE"
  exit 1
fi

echo "[$(date)] Admin token obtained" >> "$LOGFILE"

# --- Invalidate all sessions (single request) ---
TMPFILE=$(mktemp)
HTTP_CODE=$(curl -s -o "$TMPFILE" -w "%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/$REALM/logout-all" \
  -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null)

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
  echo "[$(date)] Keycloak logout completed (HTTP $HTTP_CODE)" >> "$LOGFILE"
else
  RESULT=$(cat "$TMPFILE" 2>/dev/null)
  echo "[$(date)] WARNING: Keycloak logout returned HTTP $HTTP_CODE: $RESULT" >> "$LOGFILE"
fi
rm -f "$TMPFILE"

echo "[$(date)] ===== Keycloak logout finished =====" >> "$LOGFILE"
