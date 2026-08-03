#!/bin/bash
# ============================================
# Скрипт инициализации репозитория методичек
# Создает публичный репозиторий methodical_docs
# в GitLab, доступный всем пользователям
# ============================================
#
# Вариант 1: Через GitLab API (требует админский токен)
#   ./setup_methodical_docs.sh http://gitlab.example.com <admin-token> ./docs
#
# Вариант 2: Через SSH (требует доступ к серверу GitLab)
#   ./setup_methodical_docs.sh --ssh ./docs
#
# Вариант 3: Для каждого пользователя отдельно
#   ./setup_methodical_docs.sh --for-user <username> <user-token> ./docs
# ============================================

set -e

GITLAB_URL="${1:-http://localhost:80}"
TOKEN="${2:-}"
DOCS_DIR="${3:-./docs}"
MODE="api"

# Парсинг аргументов
if [ "$1" = "--ssh" ]; then
    MODE="ssh"
    DOCS_DIR="${2:-./docs}"
    GITLAB_URL="${3:-http://localhost:80}"
elif [ "$1" = "--for-user" ]; then
    MODE="for-user"
    USERNAME="$2"
    TOKEN="$3"
    DOCS_DIR="${4:-./docs}"
    GITLAB_URL="${5:-http://localhost:80}"
fi

# Удаление последнего слэша
GITLAB_URL="${GITLAB_URL%/}"

if [ "$MODE" = "api" ]; then
    echo "=== Создание репозитория методичек через GitLab API ==="
    echo "URL: $GITLAB_URL"

    if [ -z "$TOKEN" ]; then
        echo "❌ Требуется административный токен"
        echo "Использование: $0 <gitlab-url> <admin-token> <docs-dir>"
        exit 1
    fi

    # Создаём группу methodical
    GROUP_NAME="methodical"
    GROUP_ID=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
        "$GITLAB_URL/api/v4/groups?search=$GROUP_NAME" | \
        python3 -c "
import json, sys
groups = json.load(sys.stdin)
for g in groups:
    if g['name'] == '$GROUP_NAME':
        print(g['id'])
        break
" 2>/dev/null || echo "")

    if [ -z "$GROUP_ID" ]; then
        echo "Создание группы $GROUP_NAME..."
        GROUP_ID=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
            -X POST "$GITLAB_URL/api/v4/groups" \
            -d "name=$GROUP_NAME&path=$GROUP_NAME&visibility=private" | \
            python3 -c "import json, sys; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null || echo "")
    fi

    if [ -z "$GROUP_ID" ]; then
        echo "❌ Не удалось создать группу"
        exit 1
    fi

    echo "✓ Группа создана (ID: $GROUP_ID)"

    # Создаём репозиторий в группе
    REPO_PATH="methodical_docs"
    PROJECT_ID=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
        "$GITLAB_URL/api/v4/projects?search=$REPO_PATH" | \
        python3 -c "
import json, sys
projects = json.load(sys.stdin)
for p in projects:
    if p['path'] == '$REPO_PATH':
        print(p['id'])
        break
" 2>/dev/null || echo "")

    if [ -z "$PROJECT_ID" ]; then
        echo "Создание репозитория $REPO_PATH..."
        PROJECT_ID=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
            -X POST "$GITLAB_URL/api/v4/projects" \
            -d "name=$REPO_PATH" \
            -d "namespace_id=$GROUP_ID" \
            -d "visibility=public" \
            -d "initialize_with_readme=true" | \
            python3 -c "import json, sys; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null || echo "")
    fi

    if [ -z "$PROJECT_ID" ]; then
        echo "❌ Не удалось создать репозиторий"
        exit 1
    fi

    echo "✓ Репозиторий создан: $GITLAB_URL/$GROUP_NAME/$REPO_PATH"

    # Копируем файлы
    echo "Копирование файлов..."
    for filepath in "$DOCS_DIR"/*.md; do
        [ -f "$filepath" ] || continue
        filename=$(basename "$filepath")
        content=$(cat "$filepath")
        encoded=$(echo "$content" | base64 -w 0)

        curl -s --header "PRIVATE-TOKEN: $TOKEN" \
            --header "Content-Type: application/json" \
            -X POST "$GITLAB_URL/api/v4/projects/$PROJECT_ID/repository/files/$filename" \
            -d "{\"branch\":\"main\",\"content\":\"$encoded\",\"message\":\"docs: добавлен $filename\"}" > /dev/null 2>&1

        if [ $? -eq 0 ]; then
            echo "  ✓ $filename"
        else
            echo "  ⚠ Не удалось добавить $filename"
        fi
    done

    echo ""
    echo "=== Готово ==="
    echo "Репозиторий: $GITLAB_URL/$GROUP_NAME/$REPO_PATH"
    echo "Доступен всем пользователям GitLab"

elif [ "$MODE" = "for-user" ]; then
    echo "=== Создание репозитория методичек для пользователя $USERNAME ==="

    if [ -z "$TOKEN" ]; then
        echo "❌ Требуется токен пользователя"
        exit 1
    fi

    # Создаём репозиторий
    REPO_PATH="methodical_docs"
    PROJECT_ID=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
        "$GITLAB_URL/api/v4/projects?search=$REPO_PATH" | \
        python3 -c "
import json, sys
projects = json.load(sys.stdin)
for p in projects:
    if p['path_with_namespace'].endswith('/$REPO_PATH'):
        print(p['id'])
        break
" 2>/dev/null || echo "")

    if [ -z "$PROJECT_ID" ]; then
        echo "Создание репозитория..."
        PROJECT_ID=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
            -X POST "$GITLAB_URL/api/v4/projects" \
            -d "name=$REPO_PATH" \
            -d "visibility=private" | \
            python3 -c "import json, sys; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null || echo "")
    fi

    if [ -z "$PROJECT_ID" ]; then
        echo "❌ Не удалось создать репозиторий"
        exit 1
    fi

    echo "✓ Репозиторий создан: $GITLAB_URL/$USERNAME/$REPO_PATH"

    # Копируем файлы
    echo "Копирование файлов..."
    for filepath in "$DOCS_DIR"/*.md; do
        [ -f "$filepath" ] || continue
        filename=$(basename "$filepath")
        content=$(cat "$filepath")
        encoded=$(echo "$content" | base64 -w 0)

        curl -s --header "PRIVATE-TOKEN: $TOKEN" \
            --header "Content-Type: application/json" \
            -X POST "$GITLAB_URL/api/v4/projects/$PROJECT_ID/repository/files/$filename" \
            -d "{\"branch\":\"main\",\"content\":\"$encoded\",\"message\":\"docs: добавлен $filename\"}" > /dev/null 2>&1

        if [ $? -eq 0 ]; then
            echo "  ✓ $filename"
        else
            echo "  ⚠ Не удалось добавить $filename"
        fi
    done

    echo ""
    echo "=== Готово ==="
    echo "Пользователь $USERNAME имеет репозиторий: $GITLAB_URL/$USERNAME/$REPO_PATH"

elif [ "$MODE" = "ssh" ]; then
    echo "=== Создание репозитория через SSH ==="
    echo "Для использования требуется доступ к серверу GitLab"
    echo ""
    echo "Шаги:"
    echo "1. Подключитесь к серверу GitLab по SSH"
    echo "2. Выполните:"
    echo "   git clone --bare /path/to/repo.git methodical_docs.git"
    echo "   cd methodical_docs.git"
    echo "   git push --mirror ssh://git@gitlab.example.com/group/methodical_docs.git"
    echo ""
    echo "3. Скопируйте файлы docs/:"
    echo "   rsync -avz ./docs/ git@gitlab.example.com:/var/opt/gitlab/git-data/repositories/group/methodical_docs.git/"
fi
