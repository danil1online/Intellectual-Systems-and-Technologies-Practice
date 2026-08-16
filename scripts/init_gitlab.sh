#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Инициализация GitLab: группа, админ, runner
# Этот скрипт занимается ТОЛЬКО API-запросами
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

source .env

GITLAB_BASE="${GITLAB_EXTERNAL_URL#*://}"
GITLAB_URL="http://localhost"
GITLAB_SSH_URL="ssh://git@${GITLAB_BASE%%:*}:2222"
ROOT_PASSWORD="$GITLAB_ROOT_PASSWORD"
RUNNER_SSH_KEY="$SCRIPT_DIR/shared/data/runner-keys/runner_ed25519.pub"

echo "=== GitLab: ожидание полной готовности ==="
for i in $(seq 1 90); do
    if docker exec gitlab curl -sf http://localhost:80 > /dev/null 2>&1; then
        echo "✓ GitLab готов ($i попыток)"
        break
    fi
    sleep 10
done

echo ""
echo "=== GitLab: получение root personal access token ==="

ROOT_TOKEN=$(timeout 60 docker exec gitlab gitlab-rails runner '
  user = User.find_by_username("root")
  token = user.personal_access_tokens.where(name: "setup-token").first
  if token
    puts token.token
  else
    token = user.personal_access_tokens.create!(
      name: "setup-token",
      scopes: ["api", "read_api", "read_repository", "write_repository", "admin_mode"],
      expires_at: Date.today + 365.days
    )
    puts token.token
  end
' 2>&1 | tr -d '[:space:]')

if [[ -z "$ROOT_TOKEN" ]]; then
    echo "⚠ Не удалось получить root token."
    ROOT_TOKEN="placeholder"
fi

echo "✓ Root token получен: $ROOT_TOKEN"

echo ""
echo "=== GitLab: instance CI/CD variables (DASHBOARD_USER / DASHBOARD_PASS) ==="
# auto_grade.py читает DASHBOARD_USER/DASHBOARD_PASS, чтобы POST-ить оценки в dashboard.
# В этой сборке GitLab НЕТ REST-маршрута /api/v4/ci/variables (возвращает 404),
# поэтому создаём переменные через ORM (gitlab-rails runner) — тот же механизм, что для root token.
# ШАГ НЕФАТАЛЬНЫЙ: при сбое установка не прерывается, persist в dashboard просто отключён.
create_instance_ci_vars() {
    docker exec \
        -e CIVAR_USER="${DASHBOARD_USERNAME:-admin}" \
        -e CIVAR_PASS="${DASHBOARD_PASSWORD:-}" \
        gitlab gitlab-rails runner '
          upsert = lambda do |key, val, masked|
            iv = Ci::InstanceVariable.find_or_initialize_by(key: key)
            iv.value = val
            iv.masked = masked
            iv.protected = false
            iv.save!
            puts "#{key} -> id=#{iv.id} masked=#{iv.masked?}"
          end
          upsert.call("DASHBOARD_USER", ENV.fetch("CIVAR_USER", ""), false)
          upsert.call("DASHBOARD_PASS", ENV.fetch("CIVAR_PASS", ""), true)
          puts "CI_VARS_OK count=#{Ci::InstanceVariable.count}"
        '
}
if create_instance_ci_vars; then
    echo "✓ Instance CI/CD variables для dashboard заданы"
else
    echo "⚠ Не удалось задать DASHBOARD_USER/DASHBOARD_PASS — persist будет отключён"
fi

echo ""
echo "=== GitLab: создание группы students ==="

GROUP_RESPONSE=$(curl -s --max-time 30 --request POST "$GITLAB_URL/api/v4/groups" \
  --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "name": "students",
    "path": "students",
    "visibility": "public"
  }')

GROUP_ID=$(echo "$GROUP_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")

if [[ -z "$GROUP_ID" || "$GROUP_ID" == "null" ]]; then
    GROUP_ID=$(curl -s --max-time 30 --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
      "$GITLAB_URL/api/v4/groups?search=students" \
      | jq -r '.[0].id' 2>/dev/null)
fi

if [[ -z "$GROUP_ID" ]]; then
    GROUP_ID=1
    echo "⚠ Группа создана вручную или уже существует"
else
    echo "✓ Группа students создана (ID: $GROUP_ID)"
fi

echo ""
echo "=== GitLab: создание шаблона проекта для студентов ==="

TEMPLATE_RESPONSE=$(curl -s --max-time 30 --request POST "$GITLAB_URL/api/v4/projects" \
   --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
   --header "Content-Type: application/json" \
   --data "{
     \"name\": \"project\",
     \"path\": \"project\",
     \"namespace_id\": $GROUP_ID,
     \"visibility\": \"public\"
    }")

TEMPLATE_ID=$(echo "$TEMPLATE_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")
echo "✓ Шаблон проекта: ID=$TEMPLATE_ID"

echo ""
echo "=== GitLab: инициализация структуры проекта ==="

# 1. Создаём .gitignore
GITIGNORE_CONTENT=$(base64 -w 0 << 'GITIGNOREEOF'
__pycache__/
*.pyc
.ipynb_checkpoints/
.env
*.egg-info/
dist/
build/
.DS_Store
GITIGNOREEOF
)

HTTP_CODE=$(curl -s -w "%{http_code}" --max-time 30 --request POST \
  "$GITLAB_URL/api/v4/projects/$TEMPLATE_ID/repository/files/.gitignore" \
  --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"branch\": \"main\",
    \"encoding\": \"base64\",
    \"content\": \"$GITIGNORE_CONTENT\",
    \"commit_message\": \"Add .gitignore\"
  }" -o ./.glab_response)

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    echo "✓ .gitignore создан"
elif [[ "$HTTP_CODE" == "409" ]]; then
    echo "✓ .gitignore уже существует"
else
    echo "✗ Не удалось создать .gitignore (HTTP $HTTP_CODE): $(cat ./.glab_response)"
fi

# 2. Создаём .gitkeep для пустых директорий
create_gitkeep() {
    local FILE_PATH="$1"
    local FILE_NAME="$2"
    local ENCODED_PATH=$(printf '%s/.gitkeep' "$FILE_PATH" | jq -sRr '@uri')
    local EMPTY_BASE64=$(printf '%s' "" | base64 -w 0)

    HTTP_CODE=$(curl -s -w "%{http_code}" --max-time 30 --request POST \
      "$GITLAB_URL/api/v4/projects/$TEMPLATE_ID/repository/files/$ENCODED_PATH" \
      --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
      --header "Content-Type: application/json" \
      --data "{
        \"branch\": \"main\",
        \"encoding\": \"base64\",
        \"content\": \"$EMPTY_BASE64\",
        \"commit_message\": \"Add $FILE_PATH/.gitkeep\"
      }" -o ./.glab_response)

    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
        echo "  ✓ $FILE_PATH/.gitkeep"
    elif [[ "$HTTP_CODE" == "409" ]]; then
        echo "  ✓ $FILE_PATH/.gitkeep уже существует"
    else
        echo "  ✗ Не удалось создать $FILE_PATH/.gitkeep (HTTP $HTTP_CODE): $(cat ./.glab_response)"
    fi
}

echo "Создание директорий..."

# Корневой .gitkeep (отдельный запрос, без ведущего слэша)
HTTP_CODE=$(curl -s -w "%{http_code}" --max-time 30 --request POST \
  "$GITLAB_URL/api/v4/projects/$TEMPLATE_ID/repository/files/.gitkeep" \
  --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"branch\": \"main\",
    \"encoding\": \"base64\",
    \"content\": \"\",
    \"commit_message\": \"Add .gitkeep\"
  }" -o ./.glab_response)

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    echo "  ✓ .gitkeep"
elif [[ "$HTTP_CODE" == "409" ]]; then
    echo "  ✓ .gitkeep уже существует"
else
    echo "  ✗ Не удалось создать .gitkeep (HTTP $HTTP_CODE): $(cat ./.glab_response)"
fi

echo "  → docs/.gitkeep"
create_gitkeep "docs" "docs/.gitkeep"
echo "  → notebooks/.gitkeep"
create_gitkeep "notebooks" "notebooks/.gitkeep"
echo "  → reports/.gitkeep"
create_gitkeep "reports" "reports/.gitkeep"
echo "  → docs/images/.gitkeep"
create_gitkeep "docs/images" "docs/images/.gitkeep"

# 3. Создаём README.md
README_CONTENT=$(base64 -w 0 << 'READMEEOF'
# Academic Project — Шаблон

## Структура проекта

| Папка/Файл | Назначение |
|---|---|
| `docs/` | Методические указания и инструкции |
| `notebooks/` | Практические работы (`.ipynb`) |
| `reports/` | Ваши отчёты (`.md`) |

## Начало работы

### Клонирование (HTTP)
```bash
git clone http://<server-ip>/students/project.git
```

### SSH
```bash
git clone git@gitlab.<server-ip>:students/project.git
```

## Полезные ссылки

- **JupyterHub:** http://<server-ip>:8000 — ИИ-ментор (`%%ask_mentor`)
- **Методички:** файлы в `docs/`
- **Dashboard:** http://<server-ip>:9000 — панель преподавателя
READMEEOF
)

HTTP_CODE=$(curl -s -w "%{http_code}" --max-time 30 --request POST \
  "$GITLAB_URL/api/v4/projects/$TEMPLATE_ID/repository/files/README.md" \
  --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"branch\": \"main\",
    \"encoding\": \"base64\",
    \"content\": \"$README_CONTENT\",
    \"commit_message\": \"Add README.md\"
  }" -o ./.glab_response)

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    echo "✓ README.md создан"
elif [[ "$HTTP_CODE" == "409" ]]; then
    echo "✓ README.md уже существует"
else
    echo "✗ Не удалось создать README.md (HTTP $HTTP_CODE): $(cat ./.glab_response)"
fi

# 4. Создаём .gitlab-ci.yml
# LLM_CI_* подставляются из .env, чтобы авто-оценка работала и с локальным
# LLM (контейнер `llm`, ключ local-api-key), и с внешним OpenAI-совместимым API для CI/CD.
# Заглушки __LLM_CI_*__ заменяются реальными значениями из .env (с set -u безопасными default'ами).
CI_TEXT=$(cat <<'CIEOF'
stages:
  - grade

grade:
  stage: grade
  tags:
    - istp-runner
  variables:
    GIT_STRATEGY: none
    LLM_CI_BASE_URL: "__LLM_CI_BASE_URL__"
    LLM_CI_API_KEY: "__LLM_CI_API_KEY__"
    LLM_CI_MODEL: "__LLM_CI_MODEL__"
  before_script:
    - cd /
    - rm -rf /builds/${CI_PROJECT_PATH}
    - git clone --depth 20 http://job_token:${CI_JOB_TOKEN}@gitlab:80/${CI_PROJECT_PATH}.git /builds/${CI_PROJECT_PATH}
    - cd /builds/${CI_PROJECT_PATH}
  script:
    - python /runner/scripts/auto_grade.py
  after_script:
    - rm -rf /tmp/runner-*
  artifacts:
    paths:
      - ai_report.json
    expire_in: 30 days
  only:
    - main
CIEOF
)
CI_TEXT="${CI_TEXT//__LLM_CI_BASE_URL__/${LLM_CI_BASE_URL:-http://llm:8080/v1}}"
CI_TEXT="${CI_TEXT//__LLM_CI_API_KEY__/${LLM_CI_API_KEY:-local-api-key}}"
CI_TEXT="${CI_TEXT//__LLM_CI_MODEL__/${LLM_CI_MODEL:-gpt-4o}}"
GITLAB_CI_CONTENT=$(printf '%s' "$CI_TEXT" | base64 -w 0)

HTTP_CODE=$(curl -s -w "%{http_code}" --max-time 30 --request POST \
  "$GITLAB_URL/api/v4/projects/$TEMPLATE_ID/repository/files/.gitlab-ci.yml" \
  --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"branch\": \"main\",
    \"encoding\": \"base64\",
    \"content\": \"$GITLAB_CI_CONTENT\",
    \"commit_message\": \"Add .gitlab-ci.yml for auto-grading\"
  }" -o ./.glab_response)

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    echo "✓ .gitlab-ci.yml создан"
elif [[ "$HTTP_CODE" == "409" ]]; then
    echo "✓ .gitlab-ci.yml уже существует"
else
    echo "✗ Не удалось создать .gitlab-ci.yml (HTTP $HTTP_CODE): $(cat ./.glab_response)"
fi

# 5. Копируем docs/ через git clone + push
echo "Копирование docs/..."
DOCS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../docs" && pwd)"

# Сохраняем учётные данные (один раз)
git config --global credential.helper store 2>/dev/null || true

TMP_DIR=$(mktemp -d)

# Клонируем с токеном (localhost, т.к. скрипт выполняется на хосте GitLab)
if git clone http://oauth2:$ROOT_TOKEN@localhost/students/project.git "$TMP_DIR" 2>&1; then
    # Копируем docs
    cp "$DOCS_DIR"/*.md "$TMP_DIR/docs/"
    # Копируем images в docs/images/
    mkdir -p "$TMP_DIR/docs/images"
    for ext in png jpg jpeg gif svg webp bmp; do
        cp "$DOCS_DIR/images"/*."$ext" "$TMP_DIR/docs/images/" 2>/dev/null || true
    done

    # Commit + push
    cd "$TMP_DIR"
    git add docs/
    if git commit -m "Add docs/" 2>&1; then
        git push http://oauth2:$ROOT_TOKEN@localhost/students/project.git main 2>&1
    fi

    cd "$OLDPWD"
else
    echo "  ⚠ Клонирование не удалось"
fi

rm -rf "$TMP_DIR"

echo "✓ Структура проекта инициализирована"

echo ""
echo "=== GitLab: настройка SSH deploy key для runner ==="

if [[ -f "$RUNNER_SSH_KEY" ]]; then
    SSH_PUB_KEY=$(cat "$RUNNER_SSH_KEY")

    curl -s --max-time 30 --request POST "$GITLAB_URL/api/v4/projects/$TEMPLATE_ID/deploy_keys" \
      --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
      --header "Content-Type: application/json" \
      --data "{
        \"title\": \"gitlab-runner\",
        \"key\": \"$SSH_PUB_KEY\"
      }" > /dev/null 2>&1

    echo "✓ SSH deploy key добавлена для runner"
else
    echo "⚠ SSH ключ runner не найден: $RUNNER_SSH_KEY"
fi

echo ""
echo "=== GitLab: создание локальных учётных записей лекторов ==="

# Создаём локальных пользователей-лекторов
for LECT_NUM in 01 02; do
    LECT_USER="lecturer_${LECT_NUM}"
    LECT_PASS_VAR="LECTURER_${LECT_NUM}_PASSWORD"
    LECT_PASS="${!LECT_PASS_VAR}"
    
    # Проверяем существование
    EXISTING=$(curl -s --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
      "$GITLAB_URL/api/v4/users?username=$LECT_USER" 2>/dev/null)
    
    USER_ID=$(echo "$EXISTING" | jq -r '.[0].id' 2>/dev/null || echo "")
    
    if [[ -z "$USER_ID" || "$USER_ID" == "null" ]]; then
        # Создаём пользователя
        CREATE_RESP=$(curl -s --max-time 30 --request POST "$GITLAB_URL/api/v4/users" \
          --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
          --header "Content-Type: application/json" \
          --data "{
            \"name\": \"Lecturer $LECT_NUM\",
            \"username\": \"$LECT_USER\",
            \"email\": \"lecturer${LECT_NUM}@istp.local\",
            \"password\": \"$LECT_PASS\",
            \"skip_confirmation\": true
          }")
        
        NEW_ID=$(echo "$CREATE_RESP" | jq -r '.id' 2>/dev/null || echo "")
        if [[ -n "$NEW_ID" && "$NEW_ID" != "null" ]]; then
            echo "✓ Лектор $LECT_USER создан"
        else
            echo "⚠ Не удалось создать лектора $LECT_USER: $CREATE_RESP"
        fi
    else
        echo "✓ Лектор $LECT_USER уже существует"
    fi
done

echo ""
echo "=== GitLab инициализация завершена ==="
