#!/bin/bash
set -e

TOKEN=$(grep -o '"token":"[^"]*' /opt/keycloak/.keycloak/kcadm.config | cut -d'"' -f4)

# Update lecturer_01 username
curl -s -X PUT "http://keycloak:9200/auth/admin/realms/istp/users/92d0cc4a-4dc0-455c-9461-59f41d975277" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username": "lecturer_01"}'
echo ""

# Get the updated user to verify
curl -s "http://keycloak:9200/auth/admin/realms/istp/users/92d0cc4a-4dc0-455c-9461-59f41d975277" \
  -H "Authorization: Bearer $TOKEN" | jq '{username, email}'
echo ""

# Set password
curl -s -X PUT "http://keycloak:9200/auth/admin/realms/istp/users/92d0cc4a-4dc0-455c-9461-59f41d975277/reset-password" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"password","value":"70370c3071efa36414ee153186694ee0","temporary":false}'
echo ""

# Create lecturer_02
USER_ID=$(/opt/keycloak/bin/kcadm.sh create users -r istp -s username=lecturer_02 -s email=lecturer02@istp.local -s enabled=true -s emailVerified=true -s firstName=lecturer_02 -s lastName=lecturer 2>&1 | grep -o '[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}')
echo "Created lecturer_02 with ID: $USER_ID"

# Update username to lecturer_02 (in case it used email)
/opt/keycloak/bin/kcadm.sh update users/$USER_ID -r istp -s username=lecturer_02 2>&1

# Set password
curl -s -X PUT "http://keycloak:9200/auth/admin/realms/istp/users/$USER_ID/reset-password" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"password","value":"19aef8ce852b16c4b136ec9ce0c2ec8d","temporary":false}'
echo ""

# Verify both users
echo "=== Final user list ==="
/opt/keycloak/bin/kcadm.sh get users -r istp | jq '[.[] | {username, email, enabled}]'
echo ""
echo "=== Client list ==="
/opt/keycloak/bin/kcadm.sh get clients -r istp | jq '[.[] | {clientId, enabled, redirectUris}]'
