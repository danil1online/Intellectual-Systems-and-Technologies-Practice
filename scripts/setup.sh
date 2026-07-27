#!/usr/bin/env bash
set -euo pipefail

# ============================================
# МУЛЬТИСИСТЕМНЫЙ УЧЕБНЫЙ КОМПЛЕКС
# Интерактивный инсталлятор
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}$1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
}

print_step() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

ask() {
    local prompt="$1"
    local default="$2"
    local response

    if [[ -n "$default" ]]; then
        read -rp "$prompt [$default]: " response
        if [[ -z "$response" ]]; then
            response="$default"
        fi
    else
        read -rp "$prompt: " response
    fi
    echo "$response"
}

ask_choice() {
    local prompt="$1"
    local choice1="$2"
    local text1="$3"
    local choice2="$4"
    local text2="$5"
    local default="$6"
    local response

    echo ""
    echo -e "  ${BOLD}$prompt${NC}"
    echo -e "    [1] $text1"
    echo -e "    [2] $text2"
    if [[ -n "$default" ]]; then
        echo -e "    Default: $default"
    fi
    read -rp "    Ваш выбор [1/2] [$default]: " response

    if [[ -z "$response" ]]; then
        if [[ "$default" == "1" || "$default" == "2" ]]; then
            echo "$default"
        else
            echo "1"
        fi
    else
        echo "$response"
    fi
}

generate_password() {
    openssl rand -hex 16
}

# ============================================
# ШАГ 1: Порт JupyterHub
# ============================================
print_header "ШАГ 1/7: Настройка портов"

print_step "Порт для JupyterHub (для доступа студентов к JupyterLab)"
JUPYTERHUB_PORT=$(ask "Введите порт" "8000")

print_step "Порт для панели преподавателя"
DASHBOARD_PORT=$(ask "Введите порт" "9000")

print_step "Порт для Nextcloud"
NEXTCLOUD_PORT=$(ask "Введите порт" "8080")

print_success "Порты: JupyterHub=$JUPYTERHUB_PORT, Dashboard=$DASHBOARD_PORT, Nextcloud=$NEXTCLOUD_PORT"

# ============================================
# ШАГ 1.5: Адрес GitLab
# ============================================
print_header "ШАГ 2/7: Адрес GitLab"

echo ""
echo -e "  ${BOLD}Важно:${NC}"
echo -e "  GitLab принимает только ОДИН адрес (external_url)."
echo -e "  Он влияет на clone URLs, CI/CD webhook URLs и OIDC redirects."
echo -e "  После установки изменить адрес НЕНАЗОРИЛЬНО — нужно пересоздавать volumes."
echo -e "  Укажите адрес, который будет доступен из лабсети И из интернета."
echo -e "  Формат: http://<IP_или_домен>"
echo -e ""

while true; do
    GITLAB_EXTERNAL_URL=$(ask "Адрес GitLab (http://IP_или_домен)")
    
    if [[ -z "$GITLAB_EXTERNAL_URL" ]]; then
        print_error "Адрес не может быть пустым!"
        continue
    fi
    
    # Проверка формата
    if [[ ! "$GITLAB_EXTERNAL_URL" =~ ^https?://[a-zA-Z0-9._-]+(:[0-9]+)?$ ]]; then
        print_error "Неверный формат. Примеры: http://192.168.1.100 или http://gitlab.university.edu"
        continue
    fi
    
    print_success "Адрес GitLab: $GITLAB_EXTERNAL_URL"
    break
done

REGISTRY_PORT=5050

# ============================================
# ШАГ 2: LLM для ИИ-Ментора
# ============================================
print_header "ШАГ 3/7: Настройка LLM для ИИ-Ментора"

LLM_MENTOR_TYPE=$(ask_choice \
    "Использовать для ментора:" \
    "1" "OpenAI API (уже существующий сервис)" \
    "2" "Собственный контейнер (локально)" \
    "2")

if [[ "$LLM_MENTOR_TYPE" == "1" ]]; then
    print_step "OpenAI совместимый API для ментора:"
    MENTOR_BASE=$(ask "Endpoint (IP:port, без /v1/)" "http://192.168.2.75:8080")
    LLM_MENTOR_BASE_URL="${MENTOR_BASE}/v1"
    LLM_MENTOR_API_KEY=$(ask "OpenAI API Key")
    LLM_MENTOR_TYPE="openai"
    print_success "Ментор: OpenAI API → $LLM_MENTOR_BASE_URL"
else
    print_step "Локальная модель для ментора:"
    print_warn "Скачайте модель Qwen3.5-0.8B-Q4_K_M.gguf заранее и укажите путь."
    GGUF_PATH=""

    for attempt in 1 2; do
        GGUF_PATH=$(ask "Путь к .gguf файлу" "/home/user1/Downloads/Qwen3.5-0.8B-Q4_K_M.gguf")

        if [[ -f "$GGUF_PATH" ]]; then
            print_success "Модель найдена: $GGUF_PATH"
            break
        else
            print_error "Файл не найден: $GGUF_PATH"
            if [[ "$attempt" -eq 1 ]]; then
                print_warn "Повторная попытка. Укажите правильный путь."
            else
                print_error "Вторая попытка не удалась. Модель не найдена."
                echo ""
                echo "Невозможно продолжить без модели."
                echo "Скачайте Qwen3.5-0.8B-Q4_K_M.gguf с HuggingFace:"
                echo "  https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF"
                echo "И запустите setup.sh заново."
                exit 1
            fi
        fi
    done

    GGUF_PATH="$(realpath "$GGUF_PATH")"
    
    print_step "Копирование модели в хранилище системы..."
    mkdir -p "$PROJECT_DIR/shared/data/llm-models"
    MODEL_FILE="Qwen3.5-0.8B-Q4_K_M.gguf"
    MODEL_DEST="$PROJECT_DIR/shared/data/llm-models/$MODEL_FILE"
    
    if [[ ! -f "$MODEL_DEST" ]]; then
        print_step "Копирование $GGUF_PATH -> shared/data/llm-models/ ..."
        cp "$GGUF_PATH" "$MODEL_DEST"
        
        if [[ -f "$MODEL_DEST" ]]; then
            MODEL_SIZE=$(du -h "$MODEL_DEST" | cut -f1)
            print_success "Модель скопирована (${MODEL_SIZE})"
        else
            print_error "Не удалось скопировать модель!"
            exit 1
        fi
    else
        MODEL_SIZE=$(du -h "$MODEL_DEST" | cut -f1)
        print_success "Модель уже в хранилище (${MODEL_SIZE})"
    fi
    
    # Копирование модели в Docker volume (независимо от оригинала)
    print_step "Запись модели в Docker volume..."
    if docker volume inspect llm-models >/dev/null 2>&1; then
        print_step "Volume llm-models уже существует, проверяем содержимое..."
        if docker run --rm -v llm-models:/models alpine sh -c "test -f /models/$MODEL_FILE" 2>/dev/null; then
            print_success "Модель уже в Docker volume"
        else
            print_step "Копирование модели в Docker volume..."
            docker run --rm -v llm-models:/models -v "$PROJECT_DIR/shared/data/llm-models":/source:ro alpine sh -c "cp /source/$MODEL_FILE /models/"
            if docker run --rm -v llm-models:/models alpine sh -c "test -f /models/$MODEL_FILE" 2>/dev/null; then
                print_success "Модель записана в Docker volume"
                print_warn "Оригинал в $GGUF_PATH можно удалить"
            else
                print_error "Не удалось записать модель в Docker volume"
                exit 1
            fi
        fi
    else
        print_warn "Volume llm-models не существует (будет создана при запуске)"
        print_warn "Запустите: bash scripts/setup_llm_volume.sh"
    fi
    
    LLM_MENTOR_TYPE="local"
    LLM_MENTOR_BASE_URL="http://llm:8080/v1"
    LLM_MENTOR_API_KEY="local-api-key"
    LLM_USE_LOCAL="true"
fi

# ============================================
# ШАГ 3: LLM для CI/CD
# ============================================
print_header "ШАГ 4/7: Настройка LLM для CI/CD"

LLM_CI_TYPE=$(ask_choice \
    "Использовать для CI/CD:" \
    "1" "OpenAI API (уже существующий сервис)" \
    "2" "Собственный контейнер (локально)" \
    "1")

LLM_CI_BASE_URL=""
LLM_CI_API_KEY=""

if [[ "$LLM_CI_TYPE" == "1" ]]; then
    print_step "OpenAI совместимый API для CI/CD:"
    CI_BASE=$(ask "Endpoint (IP:port, без /v1/)" "http://192.168.2.75:8080")
    LLM_CI_BASE_URL="${CI_BASE}/v1"
    LLM_CI_API_KEY=$(ask "OpenAI API Key")
    print_success "CI/CD LLM: OpenAI API → $LLM_CI_BASE_URL"
else
    # Локальная модель для CI/CD
    if [[ "$LLM_MENTOR_TYPE" == "local" ]]; then
        print_warn "Вы выбрали локальную модель и для ментора, и для CI/CD."
        print_warn "Будет использоваться та же модель ($GGUF_PATH) через один LLM-контейнер."
        LLM_CI_BASE_URL="http://llm:8080/v1"
        LLM_CI_API_KEY="local-api-key"
    else
        print_step "Локальная модель для CI/CD:"
        print_warn "Скачайте модель заранее и укажите путь."
        GGUF_PATH_CI=$(ask "Путь к .gguf файлу" "/home/user1/Downloads/Qwen3.5-0.8B-Q4_K_M.gguf")

        if [[ -f "$GGUF_PATH_CI" ]]; then
            print_success "Модель найдена: $GGUF_PATH_CI"
            GGUF_PATH_CI="$(realpath "$GGUF_PATH_CI")"
        else
            print_error "Файл не найден: $GGUF_PATH_CI"
            print_warn "Будет использован путь для ментора ($GGUF_PATH)."
            GGUF_PATH_CI="$GGUF_PATH"
        fi

        LLM_CI_BASE_URL="http://llm:8080/v1"
        LLM_CI_API_KEY="local-api-key"
    fi

    LLM_CI_TYPE="local"
fi

# ============================================
# ШАГ 4: Генерация паролей
# ============================================
print_header "ШАГ 5/7: Генерация паролей"

KC_ADMIN_PASSWORD=$(generate_password)
GITLAB_ROOT_PASSWORD=$(generate_password)
NC_ADMIN_PASSWORD=$(generate_password)
ONLYOFFICE_JWT_SECRET=$(generate_password)
JH_API_TOKEN=$(generate_password)

print_success "Keycloak admin: $(echo $KC_ADMIN_PASSWORD | cut -c1-8)... "
print_success "GitLab root: $(echo $GITLAB_ROOT_PASSWORD | cut -c1-8)... "
print_success "Nextcloud admin: $(echo $NC_ADMIN_PASSWORD | cut -c1-8)... "
print_success "OnlyOffice JWT: $(echo $ONLYOFFICE_JWT_SECRET | cut -c1-8)... "

# ============================================
# ШАГ 5: SSH-ключ для GitLab Runner
# ============================================
print_header "ШАГ 6/7: SSH-ключ для GitLab Runner"

print_step "Генерация SSH-ключа для GitLab Runner..."
mkdir -p "$PROJECT_DIR/shared/data/runner-keys"

ssh-keygen -t ed25519 -f "$PROJECT_DIR/shared/data/runner-keys/runner_ed25519" -N "" -C "gitlab-runner@academic" -q

RUNNER_SSH_PUB=$(cat "$PROJECT_DIR/shared/data/runner-keys/runner_ed25519.pub")
RUNNER_SSH_PRIV="$PROJECT_DIR/shared/data/runner-keys/runner_ed25519"

print_success "SSH-ключ сгенерирован: $RUNNER_SSH_PRIV"
print_warn "Запишите публичный ключ для добавления в GitLab (после установки):"
echo "  $RUNNER_SSH_PUB"

# ============================================
# ШАГ 6: Запись .env
# ============================================
print_header "ШАГ 7/7: Генерация конфигурации"

cat > "$PROJECT_DIR/.env" <<ENVEOF
# ============================================
# МУЛЬТИСИСТЕМНЫЙ УЧЕБНЫЙ КОМПЛЕКС
# Сгенерировано $(date '+%Y-%m-%d %H:%M:%S')
# ============================================

JUPYTERHUB_PORT=$JUPYTERHUB_PORT
DASHBOARD_PORT=$DASHBOARD_PORT
NEXTCLOUD_PORT=$NEXTCLOUD_PORT
KEYCLOAK_PORT=${KEYCLOAK_PORT:-9200}
HOST_DOMAIN=$HOST_DOMAIN
GITLAB_EXTERNAL_URL=$GITLAB_EXTERNAL_URL

REGISTRY_PORT=$REGISTRY_PORT

LLM_MENTOR_TYPE=$LLM_MENTOR_TYPE
LLM_MENTOR_BASE_URL=$LLM_MENTOR_BASE_URL
LLM_MENTOR_API_KEY=$LLM_MENTOR_API_KEY

LLM_CI_TYPE=$LLM_CI_TYPE
LLM_CI_BASE_URL=$LLM_CI_BASE_URL
LLM_CI_API_KEY=$LLM_CI_API_KEY

LLM_USE_LOCAL=$LLM_USE_LOCAL

KC_ADMIN_PASSWORD=$KC_ADMIN_PASSWORD

GITLAB_ROOT_PASSWORD=$GITLAB_ROOT_PASSWORD
GITLAB_ADMIN_TOKEN=glpat-placeholder

JH_API_TOKEN=$JH_API_TOKEN
JH_KEYCLOAK_CLIENT_ID="${JH_KEYCLOAK_CLIENT_ID}"
JH_KEYCLOAK_CLIENT_SECRET="${JH_KEYCLOAK_CLIENT_SECRET}"
DASH_CLIENT_ID=placeholder
DASH_CLIENT_SECRET=placeholder

NC_ADMIN_USER=admin
NC_ADMIN_PASSWORD=$NC_ADMIN_PASSWORD

ONLYOFFICE_JWT_SECRET=$ONLYOFFICE_JWT_SECRET
ENVEOF

chmod 600 "$PROJECT_DIR/.env"
print_success "Конфигурация записана в .env"

# ============================================
# ШАГ 7: Запуск и инициализация
# ============================================
print_header "ШАГ 8/8: Запуск сервисов"

print_step "Запуск docker-compose..."
cd "$PROJECT_DIR"

# Поднять сервисы кроме LLM (если локальный) и runner
LLM_PROFILES=""
if [[ "$LLM_USE_LOCAL" == "true" ]]; then
    LLM_PROFILES="--profile local-llm"
fi

docker compose up -d keycloak gitlab nextcloud onlyoffice admin-dashboard $LLM_PROFILES

print_step "Ожидание запуска Keycloak..."
for i in $(seq 1 30); do
    if docker inspect --format='{{.State.Health.Status}}' keycloak 2>/dev/null | grep -q "healthy"; then
        print_success "Keycloak запущен"
        break
    fi
    if [[ $i -eq 30 ]]; then
        print_error "Keycloak не запустился за 5 минут"
        exit 1
    fi
    sleep 10
done

print_step "Ожидание запуска GitLab..."
for i in $(seq 1 60); do
    if docker exec gitlab curl -sf http://localhost:80 > /dev/null 2>&1; then
        print_success "GitLab запущен"
        break
    fi
    if [[ $i -eq 60 ]]; then
        print_error "GitLab не запустился за 10 минут"
        exit 1
    fi
    sleep 10
done

print_step "Ожидание запуска Nextcloud..."
for i in $(seq 1 30); do
    if docker inspect --format='{{.State.Health.Status}}' nextcloud 2>/dev/null | grep -q "healthy"; then
        print_success "Nextcloud запущен"
        break
    fi
    if [[ $i -eq 30 ]]; then
        print_error "Nextcloud не запустился за 5 минут"
        exit 1
    fi
    sleep 10
done

if [[ "$LLM_USE_LOCAL" == "true" ]]; then
    print_step "Ожидание запуска LLM контейнера..."
    for i in $(seq 1 30); do
        if docker logs llm 2>&1 | grep -q "llama server"; then
            print_success "LLM контейнер запущен"
            break
        fi
        if [[ $i -eq 30 ]]; then
            print_warn "LLM контейнер ещё не готов (может потребоваться больше времени)"
        fi
        sleep 5
    done
fi

# ============================================
# Инициализация Keycloak
# ============================================
print_step "Инициализация Keycloak (создание OIDC клиентов)..."
bash "$SCRIPT_DIR/init_keycloak.sh"

# ============================================
# Инициализация GitLab
# ============================================
print_step "Инициализация GitLab..."
bash "$SCRIPT_DIR/init_gitlab.sh"

# ============================================
# Инициализация Nextcloud
# ============================================
print_step "Инициализация Nextcloud + OnlyOffice..."
bash "$SCRIPT_DIR/init_nextcloud.sh"

# ============================================
# Инициализация JupyterHub
# ============================================
print_step "Запуск JupyterHub (после OIDC настройки)..."

# Ждём готовности LLM (если локальный)
if [[ "$LLM_USE_LOCAL" == "true" ]]; then
    print_step "Ожидание готовности LLM..."
    for i in $(seq 1 120); do
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' llm 2>/dev/null || echo "not_found")
        if [[ "$HEALTH" == "healthy" ]]; then
            print_success "LLM готов (пройдено $((i*10)) сек)"
            break
        fi
        if [[ $i -eq 120 ]]; then
            print_warn "LLM не успел подготовиться за 20 минут"
        fi
        sleep 10
    done
fi

docker compose up -d jupyterhub

# ============================================
# Инициализация Runner
# ============================================
print_step "Регистрация GitLab Runner..."

# Ждём пока runner контейнер стартует
sleep 10

# Генерируем токен регистрации (нужен root токен GitLab)
GITLAB_URL="http://localhost"

# Получаем root токен (используем сгенерированный пароль)
# Создаём временный токен через API
ROOT_TOKEN=$(docker exec gitlab ruby -r ./lib/gitlab/current_status \
  -e 'puts "waiting..." until Gitlab::CurrentStatus.checks.ok?' 2>/dev/null || true)

# Альтернативный способ: через admin shell
RUNNER_AUTH_TOKEN=$(docker exec -it gitlab gitlab-rails runner "
  user = User.find_by_username('root')
  token = PersonalAccessTokens.create!(
    user: user,
    name: 'runner-auth',
    expires_at: Date.today + 365.days
  )
  puts token.token
" 2>/dev/null | tail -1)

if [[ -z "$RUNNER_AUTH_TOKEN" || "$RUNNER_AUTH_TOKEN" == "placeholder" ]]; then
    print_warn "Не удалось получить runner auth token из GitLab."
    print_warn "Запустите вручную после настройки GitLab:"
    echo "  docker exec -it gitlab-runner gitlab-runner register \\"
    echo "    --url http://gitlab:80 \\"
    echo "    --registration-token <ваш_registration_token>"
else
    docker exec -it gitlab-runner gitlab-runner register \
      --url http://gitlab:80 \
      --token "$RUNNER_AUTH_TOKEN" \
      --executor docker \
      --description "academic-runner" \
      --docker-image "python:3.10" \
      --locked=false \
      --tag-list "docker_runner,python3.10" \
      --docker-volumes "/cache" \
      --docker-privileged=false \
      --run-untagged=false \
      --contact-locked=false \
      2>&1 | tee -a "$PROJECT_DIR/shared/data/logs/runner_register.log"

    print_success "Runner зарегистрирован"
fi

# ============================================
# ФИНАЛЬНЫЙ ОТЧЁТ
# ============================================
print_header "УСТАНОВКА ЗАВЕРШЕНА"

echo ""
echo -e "${GREEN}Доступы:${NC}"
echo ""
echo -e "  ${BOLD}GitLab:${NC}       $GITLAB_EXTERNAL_URL"
echo -e "    Root:       root / $GITLAB_ROOT_PASSWORD"
echo -e "    Runner SSH: $RUNNER_SSH_PRIV"
echo ""
echo -e "  ${BOLD}JupyterHub:${NC}   http://localhost:$JUPYTERHUB_PORT"
echo -e "    Admin:      admin / $GITLAB_ROOT_PASSWORD (через GitLab OAuth)"
echo ""
echo -e "  ${BOLD}Nextcloud:${NC}    http://localhost:$NEXTCLOUD_PORT"
echo -e "    Admin:      $NC_ADMIN_USER / $NC_ADMIN_PASSWORD"
echo ""
echo -e "  ${BOLD}Dashboard:${NC}    http://localhost:$DASHBOARD_PORT"
echo -e "    Admin:      admin (через Keycloak OIDC)"
 echo ""
 echo -e "  ${BOLD}Keycloak:${NC}     http://localhost:$KEYCLOAK_PORT"
 echo -e "    Admin:      admin / $KC_ADMIN_PASSWORD"
echo ""

echo -e "${YELLOW}Следующие шаги:${NC}"
echo ""
echo "  1. Добавьте SSH-ключ студентам в GitLab:"
echo "     Settings → SSH Keys → добавить публичный ключ ($RUNNER_SSH_PUB)"
echo ""
echo "  2. Зарегистрируйте SSH-ключ для GitLab Runner:"
echo "     Settings → Repository → Deploy Keys → добавить $RUNNER_SSH_PUB"
echo ""
echo "  3. Инструкция по настройке студентов: docs/Pr_1.md"
echo ""
echo -e "${GREEN}Все сервисы запущены!${NC}\n"
