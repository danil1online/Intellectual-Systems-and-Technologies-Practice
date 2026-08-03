#!/bin/bash
# ============================================
# Скрипт копирования docs/ репозитория
# в учётные записи пользователей GitLab
# ============================================
# Использование:
#   ./copy_docs_to_users.sh <gitlab-url> <admin-token> <docs-source-dir>
#
# Пример:
#   ./copy_docs_to_users.sh http://192.168.1.100 MySecretAdminToken123 /path/to/docs
# ============================================

set -e

GITLAB_URL="${1:-http://localhost:80}"
ADMIN_TOKEN="${2:-}"
DOCS_DIR="${3:-./docs}"

# Удаление последнего слэша
GITLAB_URL="${GITLAB_URL%/}"

if [ -z "$ADMIN_TOKEN" ]; then
    echo "❌ Ошибка: необходим административный токен"
    echo "Использование: $0 <gitlab-url> <admin-token> <docs-source-dir>"
    exit 1
fi

if [ ! -d "$DOCS_DIR" ]; then
    echo "❌ Ошибка: директория docs не найдена: $DOCS_DIR"
    exit 1
fi

echo "=== Копирование docs/ в репозитории пользователей GitLab ==="
echo "GitLab URL: $GITLAB_URL"
echo "Docs dir: $DOCS_DIR"

# Получаем список пользователей через API
echo "Получение списка пользователей..."
USERS=$(curl -s --header "PRIVATE-TOKEN: $ADMIN_TOKEN" "$GITLAB_URL/api/v4/users?membership=true&per_page=100" | python3 -c "
import json, sys
users = json.load(sys.stdin)
for u in users:
    username = u.get('username', '')
    if username and not u.get('admin', False):
        print(username)
" 2>/dev/null || true)

if [ -z "$USERS" ]; then
    echo "⚠️ Пользователи не найдены, пробуем без фильтрации..."
    USERS=$(curl -s --header "PRIVATE-TOKEN: $ADMIN_TOKEN" "$GITLAB_URL/api/v4/users?per_page=100" | python3 -c "
import json, sys
users = json.load(sys.stdin)
for u in users:
    username = u.get('username', '')
    if username and not u.get('admin', False):
        print(username)
" 2>/dev/null || true)
fi

if [ -z "$USERS" ]; then
    echo "⚠️ Не удалось получить список пользователей"
    echo "Продолжаю с ручным указанием пользователей..."
    read -p "Введите список пользователей через пробел: " USERS
fi

echo "Найдено пользователей: $(echo "$USERS" | wc -l)"
echo ""

# Создаём репозиторий с методичками
create_docs_repo() {
    local username="$1"
    local repo_name="methodical_docs"
    local project_id=""

    echo "---"
    echo "Пользователь: $username"

    # Проверяем существование репозитория
    project_id=$(curl -s --header "PRIVATE-TOKEN: $ADMIN_TOKEN" \
        "$GITLAB_URL/api/v4/projects?search=$repo_name&simple=true" | \
        python3 -c "
import json, sys
projects = json.load(sys.stdin)
for p in projects:
    if p.get('path_with_namespace', '').endswith('$username/$repo_name'):
        print(p['id'])
        break
" 2>/dev/null || true)

    if [ -n "$project_id" ]; then
        echo "  ✓ Репозиторий уже существует (ID: $project_id)"
    else
        # Создаём новый репозиторий
        echo "  Создаём репозиторий..."
        project_id=$(curl -s --header "PRIVATE-TOKEN: $ADMIN_TOKEN" \
            -X POST "$GITLAB_URL/api/v4/projects" \
            -d "name=$repo_name" \
            -d "visibility=private" \
            -d "initialize_with_readme=true" | \
            python3 -c "import json, sys; print(json.load(sys.stdin).get('id', ''))" 2>/dev/null || true)

        if [ -n "$project_id" ]; then
            echo "  ✓ Репозиторий создан (ID: $project_id)"
        else
            echo "  ❌ Не удалось создать репозиторий"
            return 1
        fi
    fi

    # Копируем файлы docs/ в репозиторий
    echo "  Копирование файлов docs/..."

    for filepath in "$DOCS_DIR"/*.md; do
        [ -f "$filepath" ] || continue
        filename=$(basename "$filepath")

        # Читаем файл
        content=$(cat "$filepath")

        # Кодируем в base64
        encoded=$(echo "$content" | base64 -w 0)

        # Добавляем/обновляем файл в репозитории
        curl -s --header "PRIVATE-TOKEN: $ADMIN_TOKEN" \
            --header "Content-Type: application/json" \
            -X POST "$GITLAB_URL/api/v4/projects/$project_id/repository/files/$filename" \
            -d "{\"branch\":\"main\",\"content\":\"$encoded\",\"message\":\"Добавлен $filename\"}" > /dev/null 2>&1

        if [ $? -eq 0 ]; then
            echo "    ✓ $filename"
        else
            echo "    ⚠ Не удалось добавить $filename"
        fi
    done

    echo "  ✅ Готово: $GITLAB_URL/$username/$repo_name"
}

# Обрабатываем каждого пользователя
while IFS= read -r username; do
    [ -z "$username" ] && continue
    create_docs_repo "$username"
done <<< "$USERS"

echo ""
echo "=== Копирование завершено ==="
echo "Все пользователи имеют репозиторий methodical_docs с методическими материалами"
