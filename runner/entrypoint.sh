#!/bin/bash
# GitLab Runner entrypoint для Python 3.10
# Устанавливает SSH-ключи и запускает runner

set -e

echo "=== GitLab Runner Entry Point (Python 3.10) ==="

# Настройка SSH для доступа к GitLab
SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Копирование SSH-ключа runner'а
if [ -f "/runner-keys/runner_ed25519" ]; then
    cp /runner-keys/runner_ed25519 "$SSH_DIR/id_ed25519"
    cp /runner-keys/runner_ed25519.pub "$SSH_DIR/id_ed25519.pub"
    chmod 600 "$SSH_DIR/id_ed25519"
    chmod 644 "$SSH_DIR/id_ed25519.pub"
fi

# Настройка known_hosts
SSH_HOST="${GITLAB_SSH_HOST:-gitlab}"
SSH_PORT="${GITLAB_SSH_PORT:-22}"

# Добавляем host key
ssh-keyscan -p "$SSH_PORT" "$SSH_HOST" 2>/dev/null >> "$SSH_DIR/known_hosts" 2>/dev/null || true

# Настройка GIT_SSH_COMMAND
export GIT_SSH_COMMAND="ssh -i $SSH_DIR/id_ed25519 -p $SSH_PORT -o StrictHostKeyChecking=no"

echo "Runner environment configured"
echo "GitLab SSH: $GIT_SSH_COMMAND"
echo "Python version: $(python3 --version)"
echo "Jupyter version: $(jupyter --version 2>/dev/null || echo 'N/A')"

# Запуск runner
exec /usr/bin/gitlab-runner run --config /etc/gitlab-runner/config.toml
