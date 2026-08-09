#!/bin/bash
# ============================================
# JupyterHub Scheduled Logout
# Stops all active user servers
# ============================================

set -e

JUPYTERHUB_URL="http://jupyterhub:8000"
LOGFILE="/var/log/scheduled-logout.log"

echo "[$(date)] ===== JupyterHub server cleanup started =====" >> "$LOGFILE"

# --- Get list of users with active servers ---
USERS_JSON=$(curl -s "$JUPYTERHUB_URL/hub/api/users" \
  -H "Authorization: Token $JH_API_TOKEN" 2>/dev/null)

if [ -z "$USERS_JSON" ]; then
  echo "[$(date)] ERROR: Failed to fetch users from JupyterHub" >> "$LOGFILE"
  exit 1
fi

# Extract user names and their server status
# Format: {"username": {"server": null or "/user/..."}}
USERS=$(echo "$USERS_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for username, info in data.items():
        server = info.get('server', None)
        if server is not None:
            print(username)
except:
    pass
" 2>/dev/null)

if [ -z "$USERS" ]; then
  echo "[$(date)] No active servers found" >> "$LOGFILE"
  echo "[$(date)] ===== JupyterHub server cleanup finished =====" >> "$LOGFILE"
  exit 0
fi

STOPPED=0
FAILED=0

for user in $USERS; do
  # Stop the user's server
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$JUPYTERHUB_URL/hub/api/users/$user/server/stop" \
    -H "Authorization: Token $JH_API_TOKEN" 2>/dev/null)

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "202" ]; then
    echo "[$(date)] Stopped server for: $user (HTTP $HTTP_CODE)" >> "$LOGFILE"
    STOPPED=$((STOPPED + 1))
  else
    echo "[$(date)] WARNING: Failed to stop server for $user (HTTP $HTTP_CODE)" >> "$LOGFILE"
    FAILED=$((FAILED + 1))
  fi
done

echo "[$(date)] Summary: stopped=$STOPPED, failed=$FAILED" >> "$LOGFILE"
echo "[$(date)] ===== JupyterHub server cleanup finished =====" >> "$LOGFILE"
