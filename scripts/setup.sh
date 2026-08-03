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
    local default="${2:-}"
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

    echo "" >&2
    echo -e "  ${BOLD}$prompt${NC}" >&2
    echo -e "    [1] $text1" >&2
    echo -e "    [2] $text2" >&2
    if [[ -n "$default" ]]; then
        echo -e "    Default: $default" >&2
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
# АВТООПРЕДЕЛЕНИЕ СЕТЕВЫХ ПАРАМЕТРОВ
# ============================================
print_header "ШАГ 0/10: Проверка портов и автоопределение сетевых параметров"

# Проверка занятых портов
REQUIRED_PORTS="80 2222 8000 8080 9000 9200 5050"
PORTS_IN_USE=""
for port in $REQUIRED_PORTS; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} " || netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
        PORTS_IN_USE="${PORTS_IN_USE} ${port}"
        print_warn "Порт ${port} может быть занят другим процессом"
    fi
done

if [[ -n "$PORTS_IN_USE" ]]; then
    print_warn "Занятые порты:${PORTS_IN_USE}"
    print_warn "Продолжаем, но это может вызвать конфликты"
fi

# Находим все локальные IP (исключая loopback, docker, amnezia WG)
LOCAL_IPS=$(ip -4 addr show | grep -oP 'inet \K[\d.]+' | grep -v '^127\.' | grep -v '^172\.' | grep -v '10\.8\.1' | sort -u)

if [[ -z "$LOCAL_IPS" ]]; then
    print_error "Локальные IP не найдены!"
    exit 1
fi

# Берём первый не-docker IP как основной локальный
PRIMARY_LOCAL_IP=$(echo "$LOCAL_IPS" | head -1)
print_step "Основной локальный IP: $PRIMARY_LOCAL_IP"

# Находим VPN IP (amnezia WG — интерфейсы awg*)
VPN_IP=$(ip -4 addr show | grep -A1 'awg0' | grep -oP 'inet \K[\d.]+')
if [[ -z "$VPN_IP" ]]; then
    VPN_IP=$(ip -4 addr show | grep -A1 'awg' | grep -oP 'inet \K[\d.]+')
fi

if [[ -z "$VPN_IP" ]]; then
    print_warn "VPN (amnezia WG) интерфейс не найден"
    print_warn "Будет запрошен вручную"
    VPN_IP=""
else
    print_step "VPN IP (amnezia WG): $VPN_IP"
fi

# Находим подсеть и шлюз для локальной сети
SUBNET=$(ip -4 route show | grep -E "proto dhcp|proto kernel" | grep -v "172\." | grep -v "10\." | head -1 | grep -oP '([\d.]+/\d+)' || true)
DEFAULT_GW=$(ip route show default | head -1 | grep -oP 'via \K[\d.]+' || true)
PRIMARY_IFACE=$(ip route show default | head -1 | grep -oP 'dev \K\S+' || true)

print_step "Основной интерфейс: ${PRIMARY_IFACE:-авто}"
print_step "Подсеть: ${SUBNET:-авто}"
print_step "Шлюз: ${DEFAULT_GW:-авто}"

# ============================================
# ШАГ 1/10: Внешний адрес сервера
# ============================================
print_header "ШАГ 1/10: Внешний адрес сервера"

echo ""
echo -e "  ${BOLD}Внимание!${NC}"
echo -e "  Это адрес, по которому сервер будет доступен ИЗВНЕ:"
echo -e "  - Со студентовких ПК через VPN (amnezia WireGuard)"
echo -e "  - Для git clone/push/pull"
echo -e "  - Для всех OIDC callback URL"
echo -e "  - GitLab external_url (критично!)"
echo -e ""
echo -e "  Если VPN настроен — укажите VPN IP сервера (например, 10.8.1.3)"
echo -e "  Если без VPN — укажите локальный IP ($PRIMARY_LOCAL_IP)"
echo -e ""

if [[ -n "$VPN_IP" ]]; then
    print_warn "Обнаружен VPN IP: $VPN_IP"
    print_warn "Рекомендуется использовать его для внешнего доступа"
    echo ""
fi

while true; do
    EXTERNAL_IP=$(ask "Внешний IP сервера (без http://, для доступа извне)" "$PRIMARY_LOCAL_IP")
    
    if [[ -z "$EXTERNAL_IP" ]]; then
        print_error "IP не может быть пустым!"
        continue
    fi
    
    # Проверка формата IP
    if [[ ! "$EXTERNAL_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Неверный формат IP. Пример: 10.8.1.3"
        continue
    fi
    
    print_success "Внешний IP: $EXTERNAL_IP"
    break
done

# Извлекаем домен для hostname контейнеров
GITLAB_EXTERNAL_URL="http://$EXTERNAL_IP"

# Для доступа с самого сервера используем localhost
print_success "GitLab external_url: $GITLAB_EXTERNAL_URL"
print_warn "Для доступа с самого сервера используйте localhost или $PRIMARY_LOCAL_IP"
print_warn "Доступ через $EXTERNAL_IP с самого сервера потребует DNAT (настроим)"

# ============================================
# ШАГ 2/10: Порты сервисов
# ============================================
print_header "ШАГ 2/10: Порты сервисов"

print_step "Порт для JupyterHub (для доступа студентов к JupyterLab)"
JUPYTERHUB_PORT=$(ask "Введите порт" "8000")

print_step "Порт для панели преподавателя"
DASHBOARD_PORT=$(ask "Введите порт" "9000")

print_step "Порт для Nextcloud"
NEXTCLOUD_PORT=$(ask "Введите порт" "8080")

print_success "Порты: JupyterHub=$JUPYTERHUB_PORT, Dashboard=$DASHBOARD_PORT, Nextcloud=$NEXTCLOUD_PORT"

# ============================================
# ШАГ 3/10: LLM для ИИ-Ментора
# ============================================
print_header "ШАГ 3/10: Настройка LLM для ИИ-Ментора"

LLM_MENTOR_TYPE=$(ask_choice \
    "Как запустить LLM для ИИ-Ментора?" \
    "1" "OpenAI API (уже существующий внешний сервис)" \
    "2" "Локальный контейнер (загрузит свою модель)" \
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
    
    # Копирование модели в Docker volume
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
        print_step "Создание Docker volume llm-models..."
        docker volume create llm-models
        print_step "Копирование модели в Docker volume..."
        docker run --rm -v llm-models:/models -v "$PROJECT_DIR/shared/data/llm-models":/source:ro alpine sh -c "cp /source/$MODEL_FILE /models/"
        if docker run --rm -v llm-models:/models alpine sh -c "test -f /models/$MODEL_FILE" 2>/dev/null; then
            print_success "Модель записана в Docker volume"
        else
            print_error "Не удалось записать модель в Docker volume"
            exit 1
        fi
    fi
    
    LLM_MENTOR_TYPE="local"
    LLM_MENTOR_BASE_URL="http://llm:8080/v1"
    LLM_MENTOR_API_KEY="local-api-key"
    LLM_USE_LOCAL="true"
fi

# ============================================
# ШАГ 4/10: LLM для CI/CD
# ============================================
print_header "ШАГ 4/10: Настройка LLM для CI/CD"

LLM_CI_TYPE=$(ask_choice \
    "Как запустить LLM для CI/CD?" \
    "1" "OpenAI API (уже существующий внешний сервис)" \
    "2" "Локальный контейнер (загрузит свою модель)" \
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
# ШАГ 5/10: Генерация паролей
# ============================================
print_header "ШАГ 5/10: Генерация паролей"

KC_ADMIN_PASSWORD=$(generate_password)
GITLAB_ROOT_PASSWORD=$(generate_password)
NC_ADMIN_PASSWORD=$(generate_password)
JH_API_TOKEN=$(generate_password)
LECTURER_01_PASSWORD=$(generate_password)
LECTURER_02_PASSWORD=$(generate_password)
DASHBOARD_PASSWORD=$(generate_password)

print_success "Keycloak admin: $(echo $KC_ADMIN_PASSWORD | cut -c1-8)... "
print_success "GitLab root: $(echo $GITLAB_ROOT_PASSWORD | cut -c1-8)... "
print_success "Nextcloud admin: $(echo $NC_ADMIN_PASSWORD | cut -c1-8)... "
print_warn "Lecturer 01: $(echo $LECTURER_01_PASSWORD | cut -c1-8)... (смените пароль после первого входа!)"
print_warn "Lecturer 02: $(echo $LECTURER_02_PASSWORD | cut -c1-8)... (смените пароль после первого входа!)"

# ============================================
# ШАГ 6/10: SSH-ключ для GitLab Runner
# ============================================
print_header "ШАГ 6/10: SSH-ключ для GitLab Runner"

print_step "Генерация SSH-ключа для GitLab Runner..."
mkdir -p "$PROJECT_DIR/shared/data/runner-keys"

rm -f "$PROJECT_DIR/shared/data/runner-keys/runner_ed25519" "$PROJECT_DIR/shared/data/runner-keys/runner_ed25519.pub"
ssh-keygen -t ed25519 -f "$PROJECT_DIR/shared/data/runner-keys/runner_ed25519" -N "" -C "gitlab-runner@academic" -q

RUNNER_SSH_PUB=$(cat "$PROJECT_DIR/shared/data/runner-keys/runner_ed25519.pub")
RUNNER_SSH_PRIV="$PROJECT_DIR/shared/data/runner-keys/runner_ed25519"

print_success "SSH-ключ сгенерирован: $RUNNER_SSH_PRIV"
print_warn "Запишите публичный ключ для добавления в GitLab (после установки):"
echo "  $RUNNER_SSH_PUB"

# ============================================
# ШАГ 7/10: Настройка iptables DNAT
# ============================================
print_header "ШАГ 7/10: Настройка iptables DNAT"

echo ""
echo -e "  ${BOLD}Зачем это нужно:${NC}"
echo -e "  Когда вы обращаетесь к $EXTERNAL_IP с самого сервера,"
echo -e "  Linux маршрутизирует это на loopback (lo), а не на Docker."
echo -e "  DNAT перенаправляет запросы с $EXTERNAL_IP на localhost."
echo -e ""

# Проверяем, настроен ли уже DNAT
if iptables -t nat -C PREROUTING -d "$EXTERNAL_IP" -j DNAT --to-destination 127.0.0.1 2>/dev/null; then
    print_success "DNAT для $EXTERNAL_IP уже настроен"
else
    print_step "Настройка iptables DNAT для $EXTERNAL_IP → localhost..."
    
    USE_DNAT="true"
    
    # Добавляем DNAT правило
    iptables -t nat -A PREROUTING -d "$EXTERNAL_IP" -p tcp -j DNAT --to-destination 127.0.0.1 2>/dev/null || {
        print_warn "Не удалось добавить iptables правило (возможно, нет прав root)"
        print_warn "DNAT нужно настроить вручную или запустить setup.sh с sudo"
        USE_DNAT="false"
    }
    
    if [[ "${USE_DNAT}" == "true" ]]; then
        # Проверяем, что правило добавилось
        if iptables -t nat -C PREROUTING -d "$EXTERNAL_IP" -p tcp -j DNAT --to-destination 127.0.0.1 2>/dev/null; then
            print_success "DNAT настроен: $EXTERNAL_IP → 127.0.0.1"
            
            # Сохраняем правило для persistency
            mkdir -p "$PROJECT_DIR/shared/scripts"
            cat > "$PROJECT_DIR/shared/scripts/setup-dnat.sh" << DNATEOF
#!/bin/bash
# DNAT правило для VPN IP -> localhost
# Добавлено: $(date '+%Y-%m-%d %H:%M:%S')
iptables -t nat -A PREROUTING -d $EXTERNAL_IP -p tcp -j DNAT --to-destination 127.0.0.1 2>/dev/null || true
DNATEOF
            chmod +x "$PROJECT_DIR/shared/scripts/setup-dnat.sh"
            print_success "Скрипт сохранения правил: shared/scripts/setup-dnat.sh"
        else
            print_error "Не удалось настроить DNAT"
        fi
    fi
fi

# Сохраняем локальный IP для дальнейшей настройки
print_success "Локальный IP для iptables: $PRIMARY_LOCAL_IP"

# ============================================
# ШАГ 8/10: Запись .env
# ============================================
print_header "ШАГ 8/10: Генерация конфигурации"

# Генерируем OIDC секреты
OIDC_GITLAB_SECRET=$(openssl rand -hex 32)
OIDC_JUPYTER_SECRET=$(openssl rand -hex 32)
OIDC_NEXTCLOUD_SECRET=$(openssl rand -hex 32)
OIDC_DASHBOARD_SECRET=$(openssl rand -hex 32)
OIDC_REGISTRY_SECRET=$(openssl rand -hex 32)

# Извлекаем чистый IP из GITLAB_EXTERNAL_URL
GITLAB_HOST=$(echo "$GITLAB_EXTERNAL_URL" | sed 's|http://||' | sed 's|:.*||')

cat > "$PROJECT_DIR/.env" <<ENVEOF
# ============================================
# МУЛЬТИСИСТЕМНЫЙ УЧЕБНЫЙ КОМПЛЕКС
# Сгенерировано $(date '+%Y-%m-%d %H:%M:%S')
# ============================================

# --- Сетевые параметры ---
# Внешний IP (для доступа из VPN/лабсети) — используется как GitLab external_url
GITLAB_HOST=$GITLAB_HOST
GITLAB_EXTERNAL_URL=$GITLAB_EXTERNAL_URL
# Локальный IP сервера (для доступа из той же подсети)
LOCAL_IP=$PRIMARY_LOCAL_IP
# Для доступа с самого сервера (localhost)
HOST_IP_LOCAL=localhost

# Порты
JUPYTERHUB_PORT=$JUPYTERHUB_PORT
DASHBOARD_PORT=$DASHBOARD_PORT
NEXTCLOUD_PORT=$NEXTCLOUD_PORT
KEYCLOAK_PORT=9200
REGISTRY_PORT=5050

# --- LLM ---
LLM_MENTOR_TYPE=$LLM_MENTOR_TYPE
LLM_MENTOR_BASE_URL=$LLM_MENTOR_BASE_URL
LLM_MENTOR_API_KEY=$LLM_MENTOR_API_KEY
LLM_CI_TYPE=$LLM_CI_TYPE
LLM_CI_BASE_URL=$LLM_CI_BASE_URL
LLM_CI_API_KEY=$LLM_CI_API_KEY
LLM_USE_LOCAL=$LLM_USE_LOCAL

# --- Keycloak ---
KC_ADMIN_PASSWORD=$KC_ADMIN_PASSWORD

# --- Лекторы ---
LECTURER_01_PASSWORD=$LECTURER_01_PASSWORD
LECTURER_02_PASSWORD=$LECTURER_02_PASSWORD

# --- GitLab ---
GITLAB_ROOT_PASSWORD=$GITLAB_ROOT_PASSWORD
GITLAB_ADMIN_TOKEN=glpat-placeholder

# --- JupyterHub ---
JH_API_TOKEN=$JH_API_TOKEN

# --- Dashboard ---
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD

# --- OIDC секреты ---
OIDC_GITLAB_SECRET=$OIDC_GITLAB_SECRET
OIDC_JUPYTER_SECRET=$OIDC_JUPYTER_SECRET
OIDC_NEXTCLOUD_SECRET=$OIDC_NEXTCLOUD_SECRET
OIDC_DASHBOARD_SECRET=$OIDC_DASHBOARD_SECRET
OIDC_REGISTRY_SECRET=$OIDC_REGISTRY_SECRET

DASH_CLIENT_ID=admin-dashboard
DASH_CLIENT_SECRET=$OIDC_DASHBOARD_SECRET

NC_ADMIN_USER=admin
NC_ADMIN_PASSWORD=$NC_ADMIN_PASSWORD
ENVEOF

chmod 600 "$PROJECT_DIR/.env"
print_success "Конфигурация записана в .env"

# ============================================
# ШАГ 9/10: Очистка и запуск сервисов
# ============================================
print_header "ШАГ 9/10: Очистка и запуск"

print_step "Очистка предыдущих данных сервисов..."
cd "$PROJECT_DIR"

# Удаляем bind-mounted данные GitLab
if [ -d "$PROJECT_DIR/shared/data/gitlab-data" ]; then
    docker run --rm -v "$PROJECT_DIR/shared/data/gitlab-data:/data" alpine sh -c "rm -rf /data/* /data/.* 2>/dev/null; mkdir -p /data" 2>/dev/null || true
    print_success "GitLab data очищен"
fi
if [ -d "$PROJECT_DIR/shared/data/gitlab-config" ]; then
    docker run --rm -v "$PROJECT_DIR/shared/data/gitlab-config:/config" alpine sh -c "rm -rf /config/* /config/.* 2>/dev/null; mkdir -p /config" 2>/dev/null || true
    print_success "GitLab config очищен"
fi
if [ -d "$PROJECT_DIR/shared/data/runner-config" ]; then
    docker run --rm -v "$PROJECT_DIR/shared/data/runner-config:/runner" alpine sh -c "rm -rf /runner/* /runner/.* 2>/dev/null; mkdir -p /runner" 2>/dev/null || true
    print_success "Runner config очищен"
fi

if [ -d "$PROJECT_DIR/shared/data/nextcloud-data" ]; then
    rm -rf "$PROJECT_DIR/shared/data/nextcloud-data"
    print_success "Nextcloud data очищен"
fi

# Удаляем Docker тома
print_step "Удаление Docker томов..."
for vol in keycloak-data kc-postgres-data nextcloud-data nextcloud-config nextcloud-custom nextcloud-data-merged; do
    docker volume rm "$vol" 2>/dev/null && print_success "Том $vol удалён" || true
done

print_step "Очистка завершена"

# Запуск
print_header "ШАГ 10/10: Запуск сервисов"

print_step "Запуск docker-compose..."

LLM_PROFILES=""
if [[ "$LLM_USE_LOCAL" == "true" ]]; then
    LLM_PROFILES="--profile local-llm"
fi

if [[ -n "$LLM_PROFILES" ]]; then
    docker compose $LLM_PROFILES up -d keycloak gitlab nextcloud admin-dashboard
else
    docker compose up -d keycloak gitlab nextcloud admin-dashboard
fi

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
# Инициализация сервисов
# ============================================
print_step "Инициализация GitLab (группы, runner)..."
bash "$SCRIPT_DIR/init_gitlab.sh"

print_step "Инициализация Nextcloud (OIDC)..."
bash "$SCRIPT_DIR/init_nextcloud.sh"

print_step "Запуск JupyterHub..."
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
# Регистрация GitLab Runner
# ============================================
print_step "Регистрация GitLab Runner..."

print_step "Ожидание готовности GitLab для регистрации Runner..."
for i in $(seq 1 90); do
    if docker exec gitlab curl -sf http://localhost:80 > /dev/null 2>&1; then
        print_success "GitLab готов для Runner ($i попыток)"
        break
    fi
    sleep 10
done

print_step "Получение root Personal Access Token..."
ROOT_TOKEN=$(timeout 60 docker exec gitlab gitlab-rails runner '
  user = User.find_by_username("root")
  token = user.personal_access_tokens.where(name: "runner-setup-token").first
  if token
    puts token.token
  else
    token = user.personal_access_tokens.create!(
      name: "runner-setup-token",
      scopes: ["api", "admin_mode"],
      expires_at: Date.today + 365.days
    )
    puts token.token
  end
' 2>&1 | tr -d '[:space:]' | grep "glpat-" | head -1)

if [[ -z "$ROOT_TOKEN" ]]; then
    print_error "Не удалось получить root PAT"
    exit 1
fi
print_success "Root PAT получен"

print_step "Создание Runner в GitLab через API..."
RUNNER_RESPONSE=$(curl -s --request POST --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"name": "academic-runner", "runner_type": "group_type"}' \
  "http://localhost/api/v4/runners" 2>&1 | tee -a "$PROJECT_DIR/shared/data/logs/runner_register.log")

RUNNER_TOKEN=$(echo "$RUNNER_RESPONSE" | jq -r '.token' 2>/dev/null)
RUNNER_ID=$(echo "$RUNNER_RESPONSE" | jq -r '.id' 2>/dev/null)

if [[ -z "$RUNNER_TOKEN" || "$RUNNER_TOKEN" == "null" ]]; then
    print_error "Не удалось получить токен Runner"
    exit 1
fi

echo "Runner ID: $RUNNER_ID"
echo "Runner Token: $RUNNER_TOKEN"

RUNNER_CONFIG="$PROJECT_DIR/shared/data/runner-config/config.toml"
mkdir -p "$PROJECT_DIR/shared/data/runner-config"
cat > "$RUNNER_CONFIG" << RUNNEREOF
concurrent = 4
check_interval = 0
shutdown_request_timeout = 0s

[session_server]
  session_timeout = 1800

[[runners]]
  name = "academic-runner"
  url = "http://$GITLAB_HOST"
  token = "$RUNNER_TOKEN"
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
  [runners.docker]
    image = "python:3.10"
    privileged = false
    disable_entrypoint_overrides = false
    pull_policy = "if-not-present"
    shm_size = 0
RUNNEREOF

print_success "config.toml записан"
print_success "Runner создан (ID: $RUNNER_ID, Token: $RUNNER_TOKEN)"

# ============================================
# ФИНАЛЬНЫЙ ОТЧЁТ
# ============================================
print_header "УСТАНОВКА ЗАВЕРШЕНА"

echo ""
echo -e "${GREEN}Доступы:${NC}"
echo ""
echo -e "  ${BOLD}С других ПК (через VPN/лабсеть):${NC}"
echo ""
echo -e "  ${BOLD}Keycloak:${NC}      http://$EXTERNAL_IP:$KEYCLOAK_PORT/auth/realms/istp"
echo -e "  ${BOLD}GitLab:${NC}        http://$EXTERNAL_IP"
echo -e "    Root:        root / $GITLAB_ROOT_PASSWORD"
echo -e "    Lecturer:    lecturer_01 / $LECTURER_01_PASSWORD (смените!)"
echo -e "    Lecturer:    lecturer_02 / $LECTURER_02_PASSWORD (смените!)"
echo -e "    Git clone:   git clone http://$EXTERNAL_IP/students/project.git"
echo -e "    Git SSH:     git@gitlab.$GITLAB_HOST:students/project.git"
echo -e "    Runner SSH:  $RUNNER_SSH_PRIV"
echo ""
echo -e "  ${BOLD}JupyterHub:${NC}    http://$EXTERNAL_IP:$JUPYTERHUB_PORT"
echo -e "    Вход через:    Keycloak (кнопка на странице входа)"
echo ""
echo -e "  ${BOLD}Nextcloud:${NC}     http://$EXTERNAL_IP:$NEXTCLOUD_PORT"
echo -e "    Admin:       $NC_ADMIN_USER / $NC_ADMIN_PASSWORD"
echo ""
echo -e "  ${BOLD}Dashboard:${NC}     http://$EXTERNAL_IP:$DASHBOARD_PORT"
echo -e "    Admin:       admin / $DASHBOARD_PASSWORD (Basic Auth)"
echo ""

echo -e "  ${BOLD}С этого сервера:${NC}"
echo ""
echo -e "  ${BOLD}Keycloak:${NC}      http://localhost:$KEYCLOAK_PORT/auth/realms/istp"
echo -e "  ${BOLD}GitLab:${NC}        http://localhost (или http://$PRIMARY_LOCAL_IP)"
echo -e "  ${BOLD}JupyterHub:${NC}    http://localhost:$JUPYTERHUB_PORT"
echo -e "  ${BOLD}Nextcloud:${NC}     http://localhost:$NEXTCLOUD_PORT"
echo -e "  ${BOLD}Dashboard:${NC}     http://localhost:$DASHBOARD_PORT"
echo ""

if [[ "${USE_DNAT}" == "true" ]]; then
    echo -e "  ${BOLD}Через VPN IP ($EXTERNAL_IP):${NC}"
    echo -e "  DNAT настроен — $EXTERNAL_IP перенаправляется на localhost"
    echo -e "  Скрипт persistency: shared/scripts/setup-dnat.sh"
    echo -e ""
fi

echo -e "${YELLOW}Следующие шаги:${NC}"
echo ""
echo "  1. Студенты регистрируются: GitLab → Sign in → Keycloak → Register"
echo "     Или напрямую: http://$EXTERNAL_IP:$KEYCLOAK_PORT/auth/realms/istp/login-actions/registration"
echo ""
echo "  2. Git clone/push/pull с студентовких ПК:"
echo "     git clone http://$EXTERNAL_IP/students/project.git"
echo "     git remote add origin http://$EXTERNAL_IP/students/project.git"
echo ""
echo "  3. SSH доступ к GitLab:"
echo "     ssh-keygen -t ed25519 -C student@pc"
echo "     # добавить публичный ключ в GitLab → Settings → SSH Keys"
echo "     git clone git@gitlab.$GITLAB_HOST:students/project.git"
echo ""
echo "  4. Инструкция по настройке студентов: docs/Pr_1.md"
echo ""
echo -e "${YELLOW}Архитектура:${NC}"
echo "  - Keycloak: единый Identity Provider для всех сервисов"
echo "  - Self-registration: студенты регистрируются через Keycloak"
echo "  - GitLab: OIDC авторизация через Keycloak"
echo "  - JupyterHub: OIDC авторизация через Keycloak"
echo "  - Nextcloud: OIDC авторизация через Keycloak"
echo ""
echo -e "${GREEN}Все сервисы запущены!${NC}\n"
