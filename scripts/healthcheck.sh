#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
cd "$PROJECT_DIR"

SERVICES=("zitadel" "gitlab" "gitlab-runner" "jupyterhub" "nextcloud" "onlyoffice" "admin-dashboard")
HEALTHY=0
UNHEALTHY=0

echo "=== Health Check ==="

for svc in "${SERVICES[@]}"; do
    status=$(docker inspect --format='{{.State.Status}}' "$svc" 2>/dev/null || echo "not_found")
    health=$(docker inspect --format='{{.State.Health.Status}}' "$svc" 2>/dev/null || echo "N/A")

    if [[ "$status" == "running" ]]; then
        if [[ "$health" == "healthy" || "$health" == "N/A" ]]; then
            echo -e "  \033[0;32m[✓]\033[0m $svc: running (health: $health)"
            HEALTHY=$((HEALTHY + 1))
        else
            echo -e "  \033[1;33m[!]\033[0m $svc: running (health: $health)"
            HEALTHY=$((HEALTHY + 1))
        fi
    else
        echo -e "  \033[0;31m[✗]\033[0m $svc: $status"
        UNHEALTHY=$((UNHEALTHY + 1))
    fi
done

echo ""
echo "Healthy: $HEALTHY, Unhealthy: $UNHEALTHY"

if [[ $UNHEALTHY -gt 0 ]]; then
    exit 1
fi
