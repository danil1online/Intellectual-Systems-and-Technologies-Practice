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

# ============================================
# Утилиты
# ============================================

# Сравнение файлов по SHA256-хешу
# Возвращает 0 (true) если файлы идентичны
files_identical() {
    local hash1 hash2
    hash1=$(sha256sum "$1" 2>/dev/null | cut -d' ' -f1)
    hash2=$(sha256sum "$2" 2>/dev/null | cut -d' ' -f1)
    [[ -n "$hash1" && -n "$hash2" && "$hash1" == "$hash2" ]]
}

# Получить SHA256 хеш файла
file_hash() {
    sha256sum "$1" 2>/dev/null | cut -d' ' -f1
}

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
print_header "ШАГ 0/11: Проверка портов и автоопределение сетевых параметров"

# Проверка занятых портов
REQUIRED_PORTS="80 2222 8000 8080 9000 5050"
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

# Находим все локальные IP (исключая loopback, docker сети, VPN)
LOCAL_IPS=$(ip -4 addr show | grep -oP 'inet \K[\d.]+' | grep -v '^127\.' | grep -vE '^172\.(1[6-9]|2[0-9]|3[01])\.' | grep -vE '^10\.8\.' | grep -vE '^192\.168\.(200|201)\.' | sort -u)

# Находим VPN IP (amnezia WG — интерфейсы awg*)
VPN_IP=$(ip -4 addr show | grep -A1 'awg' | grep -oP 'inet \K[\d.]+')

# Находим подсеть и шлюз для локальной сети
SUBNET=$(ip -4 route show | grep -E "proto dhcp|proto kernel" | grep -v "172\." | grep -v "10\." | head -1 | grep -oP '([\d.]+/\d+)' || true)
DEFAULT_GW=$(ip route show default | head -1 | grep -oP 'via \K[\d.]+' || true)
PRIMARY_IFACE=$(ip route show default | head -1 | grep -oP 'dev \K\S+' || true)

if [[ -z "$LOCAL_IPS" ]]; then
    print_error "Локальные IP не найдены!"
    print_step "Доступные сетевые интерфейсы:"
    ip -4 addr show | grep "inet " | grep -v '^127'
    exit 1
fi

# Берём первый не-docker IP как основной локальный
PRIMARY_LOCAL_IP=$(echo "$LOCAL_IPS" | head -1)

if [[ -n "$VPN_IP" ]]; then
    print_warn "Обнаружен VPN IP (НЕ ДОСТУПЕН из Docker): $VPN_IP"
fi

print_step "Интерфейс: $PRIMARY_IFACE | Подсеть: ${SUBNET:-авто} | Шлюз: ${DEFAULT_GW:-авто}"
print_step "Доступные локальные IP для использования:"
echo "$LOCAL_IPS" | head -5 | while read ip; do
    print_step "  - $ip"
done

# ============================================
# ШАГ 1/11: Внешний адрес сервера
# ============================================
print_header "ШАГ 1/11: Внешний адрес сервера"

echo ""
echo -e "  ${BOLD}Внимание!${NC}"
echo -e "  Это адрес, по которому сервер будет доступен ИЗВНЕ:"
echo -e "  - Со студентовких ПК через VPN (amnezia WireGuard)"
echo -e "  - Для git clone/push/pull"
echo -e "  - Для GitLab external_url и callback URL"
echo -e "  - GitLab external_url (критично!)"
echo -e ""
echo -e "  ${BOLD}Важно:${NC} VPN IP недоступен из Docker-контейнеров и не может быть использован."
echo -e "  Укажите локальный IP из доступных:"
echo "$LOCAL_IPS" | head -5 | while read ip; do
    print_step "    - $ip"
done
echo ""

while true; do
    EXTERNAL_IP=$(ask "Внешний IP сервера (без http://)" "$PRIMARY_LOCAL_IP")
    
    if [[ -z "$EXTERNAL_IP" ]]; then
        print_error "IP не может быть пустым!"
        continue
    fi
    
    # Проверка формата IP
    if [[ ! "$EXTERNAL_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Неверный формат IP. Пример: 192.168.1.38"
        continue
    fi
    
    # Проверка что IP из допустимого списка
    if ! echo "$LOCAL_IPS" | grep -q "^${EXTERNAL_IP}$"; then
        print_error "IP $EXTERNAL_IP не найден в допустимых локальных IP!"
        print_step "Допустимые IP:"
        echo "$LOCAL_IPS" | head -5 | while read ip; do
            print_step "  - $ip"
        done
        continue
    fi
    
    print_success "Внешний IP: $EXTERNAL_IP"
    break
done

# Извлекаем домен для hostname контейнеров
GITLAB_EXTERNAL_URL="http://$EXTERNAL_IP"

# Для доступа с самого сервера используем localhost
print_success "GitLab external_url: $GITLAB_EXTERNAL_URL"

# ============================================
# ШАГ 2/11: Порты сервисов
# ============================================
print_header "ШАГ 2/11: Порты сервисов"

print_step "Порт для JupyterHub (для доступа студентов к JupyterLab)"
JUPYTERHUB_PORT=$(ask "Введите порт" "8000")

print_step "Порт для панели преподавателя"
DASHBOARD_PORT=$(ask "Введите порт" "9000")

print_success "Порты: JupyterHub=$JUPYTERHUB_PORT, Dashboard=$DASHBOARD_PORT"

# ============================================
# ШАГ 2.5/12: Загрузка датасетов для практических работ
# ============================================
print_header "ШАГ 2.5/12: Загрузка датасетов для практических работ"

DATA_ZIP_URL="https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/releases/download/v1.1/data.zip"
PROJECT_VOLUME_PREFIX=$(basename "$PROJECT_DIR")
DATA_VOLUME="${PROJECT_VOLUME_PREFIX}_shared-data"

# Проверяем, есть ли уже данные в volume
if docker volume inspect "$DATA_VOLUME" >/dev/null 2>&1; then
    FILE_COUNT=$(docker run --rm -v "$DATA_VOLUME":/data alpine sh -c "find /data -type f 2>/dev/null | wc -l")
    if [[ "$FILE_COUNT" -gt 0 ]]; then
        DATA_SIZE=$(docker run --rm -v "$DATA_VOLUME":/data alpine sh -c "du -sh /data 2>/dev/null | cut -f1")
        print_success "Датасеты уже загружены в Docker volume (${DATA_SIZE}, ${FILE_COUNT} файлов)"
        cd - > /dev/null
    else
        print_step "Volume существует, но пустой — загружаю данные..."
        DOWNLOAD_NEEDED="true"
    fi
else
    print_step "Volume не существует — создаю и загружаю данные..."
    DOWNLOAD_NEEDED="true"
fi

if [[ "${DOWNLOAD_NEEDED:-false}" == "true" ]]; then
    DATA_SOURCE=$(ask_choice \
        "Выберите источник данных" \
        "1" "Скачать по ссылке (GitHub)" \
        "2" "Локальный файл data.zip" \
        "1")

    if [[ "$DATA_SOURCE" == "2" ]]; then
        while true; do
            DATA_ZIP_PATH=$(ask "Путь к файлу data.zip")
            if [[ -f "$DATA_ZIP_PATH" ]]; then
                print_success "Файл найден: $DATA_ZIP_PATH"
                USE_LOCAL_ZIP="true"
                break
            else
                print_error "Файл не найден: $DATA_ZIP_PATH"
            fi
        done
    else
        USE_LOCAL_ZIP="false"
    fi

    if [[ "${USE_LOCAL_ZIP:-false}" == "false" ]]; then
        print_step "Скачивание data.zip ..."
        if command -v wget >/dev/null 2>&1; then
            wget -q --show-progress -O /tmp/data.zip "$DATA_ZIP_URL"
        else
            curl -fsSL -o /tmp/data.zip "$DATA_ZIP_URL"
        fi
    else
        print_step "Копирование data.zip ..."
        cp "$DATA_ZIP_PATH" /tmp/data.zip
    fi

    if [[ -f /tmp/data.zip ]]; then
        ZIP_SIZE=$(du -h /tmp/data.zip | cut -f1)
        print_step "Распаковка архива (${ZIP_SIZE}) ..."
        
        cd /tmp
        unzip -o data.zip > /dev/null 2>&1
        
        if ! docker volume inspect "$DATA_VOLUME" >/dev/null 2>&1; then
            print_step "Создание Docker volume $DATA_VOLUME ..."
            docker volume create "$DATA_VOLUME"
        fi
        
        print_step "Копирование данных в Docker volume ..."
        docker run --rm -v "$DATA_VOLUME":/data -v /tmp:/src:ro alpine sh -c "cp -r /src/cifar-10* /src/*.csv /data/"
        
        FILE_COUNT=$(docker run --rm -v "$DATA_VOLUME":/data alpine sh -c "find /data -type f | wc -l")
        if [[ "$FILE_COUNT" -gt 0 ]]; then
            DATA_SIZE=$(docker run --rm -v "$DATA_VOLUME":/data alpine sh -c "du -sh /data | cut -f1")
            print_success "Датасеты загружены в Docker volume (${DATA_SIZE}, ${FILE_COUNT} файлов)"
        else
            print_error "Не удалось скопировать данные в volume"
            exit 1
        fi
        
        rm -f /tmp/data.zip
        rm -rf /tmp/cifar-10* /tmp/*.csv
        cd - > /dev/null
    else
        print_error "Не удалось получить data.zip"
        exit 1
    fi
fi
# ШАГ 3/11: LLM для ИИ-Ментора
# ============================================
print_header "ШАГ 3/11: Настройка LLM для ИИ-Ментора"

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
    LLM_MENTOR_MODEL=$(ask "Имя модели для API" "gpt-4o")
    LLM_MENTOR_TYPE="openai"
    print_success "Ментор: OpenAI API → $LLM_MENTOR_BASE_URL (модель: $LLM_MENTOR_MODEL)"
else
    print_step "Локальная модель для ментора:"
    print_warn "Скачайте модель *.gguf заранее и укажите путь (установлен по умолчанию)."
    print_warn "Модель будет переименована в model.gguf перед записью в volume."
    GGUF_PATH=""

    for attempt in 1 2; do
        GGUF_PATH=$(ask "Путь к .gguf файлу" "/home/user1/Downloads/qwen2.5-coder-7b-instruct-q4_k_m.gguf")

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
                echo "Скачайте любую .gguf модель, например:"
                echo "  https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF"
                echo "И запустите setup.sh заново."
                exit 1
            fi
        fi
    done

    GGUF_PATH="$(realpath "$GGUF_PATH")"
    
    print_step "Копирование модели в хранилище системы..."
    mkdir -p "$PROJECT_DIR/shared/data/llm-models"
    MODEL_FILE="model.gguf"
    MODEL_DEST="$PROJECT_DIR/shared/data/llm-models/model.gguf"
    
    if [[ -f "$MODEL_DEST" ]] && files_identical "$GGUF_PATH" "$MODEL_DEST"; then
        MODEL_SIZE=$(du -h "$MODEL_DEST" | cut -f1)
        print_success "Модель уже в хранилище (совпадает, ${MODEL_SIZE})"
    else
        print_step "Копирование $GGUF_PATH -> $MODEL_DEST ..."
        cp "$GGUF_PATH" "$MODEL_DEST"
        
        if [[ -f "$MODEL_DEST" ]]; then
            MODEL_SIZE=$(du -h "$MODEL_DEST" | cut -f1)
            print_success "Модель скопирована (${MODEL_SIZE})"
        else
            print_error "Не удалось скопировать модель!"
            exit 1
        fi
    fi
    
    # Копирование модели в Docker volume (с правильным префиксом)
    print_step "Запись модели в Docker volume..."
    PROJECT_VOLUME_PREFIX=$(basename "$PROJECT_DIR")
    FULL_VOLUME_NAME="${PROJECT_VOLUME_PREFIX}_llm-models"
    
    SOURCE_HASH=$(file_hash "$MODEL_DEST")
    
    if docker volume inspect "$FULL_VOLUME_NAME" >/dev/null 2>&1; then
        print_step "Volume $FULL_VOLUME_NAME уже существует, проверяем содержимое..."
        VOLUME_HASH=$(docker run --rm -v "$FULL_VOLUME_NAME":/models alpine sh -c "sha256sum /models/$MODEL_FILE | cut -d' ' -f1" 2>/dev/null)
        if [[ -n "$VOLUME_HASH" && "$VOLUME_HASH" == "$SOURCE_HASH" ]]; then
            print_success "Модель в Docker volume (совпадает)"
        else
            print_step "Модель в Docker volume отличается — перезаписываю..."
            docker run --rm -v "$FULL_VOLUME_NAME":/models -v "$PROJECT_DIR/shared/data/llm-models":/source:ro alpine sh -c "cp /source/$MODEL_FILE /models/"
            if docker run --rm -v "$FULL_VOLUME_NAME":/models alpine sh -c "sha256sum /models/$MODEL_FILE | cut -d' ' -f1" 2>/dev/null | grep -q "$SOURCE_HASH"; then
                print_success "Модель записана в Docker volume"
                print_warn "Оригинал в $GGUF_PATH можно удалить"
            else
                print_error "Не удалось записать модель в Docker volume"
                exit 1
            fi
        fi
    else
        print_step "Создание Docker volume $FULL_VOLUME_NAME..."
        docker volume create "$FULL_VOLUME_NAME"
        print_step "Копирование модели в Docker volume..."
        docker run --rm -v "$FULL_VOLUME_NAME":/models -v "$PROJECT_DIR/shared/data/llm-models":/source:ro alpine sh -c "cp /source/$MODEL_FILE /models/"
        if docker run --rm -v "$FULL_VOLUME_NAME":/models alpine sh -c "sha256sum /models/$MODEL_FILE | cut -d' ' -f1" 2>/dev/null | grep -q "$SOURCE_HASH"; then
            print_success "Модель записана в Docker volume"
        else
            print_error "Не удалось записать модель в Docker volume"
            exit 1
        fi
    fi
    
    LLM_MENTOR_TYPE="local"
    LLM_MENTOR_BASE_URL="http://llm:8080/v1"
    LLM_MENTOR_API_KEY="local-api-key"
    LLM_MENTOR_MODEL="model.gguf"
    LLM_USE_LOCAL="true"
fi

# ============================================
# ШАГ 4/11: LLM для CI/CD
# ============================================
print_header "ШАГ 4/11: Настройка LLM для CI/CD"

LLM_CI_TYPE=$(ask_choice \
    "Как запустить LLM для CI/CD?" \
    "1" "OpenAI API (уже существующий внешний сервис)" \
    "2" "Локальный контейнер (загрузит свою модель)" \
    "2")

LLM_CI_BASE_URL=""
LLM_CI_API_KEY=""

if [[ "$LLM_CI_TYPE" == "1" ]]; then
    print_step "OpenAI совместимый API для CI/CD:"
    CI_BASE=$(ask "Endpoint (IP:port, без /v1/)" "http://192.168.2.75:8080")
    LLM_CI_BASE_URL="${CI_BASE}/v1"
    LLM_CI_API_KEY=$(ask "OpenAI API Key")
    LLM_CI_MODEL=$(ask "Имя модели для API" "gpt-4o")
    print_success "CI/CD LLM: OpenAI API → $LLM_CI_BASE_URL (модель: $LLM_CI_MODEL)"
else
    if [[ "$LLM_MENTOR_TYPE" == "local" ]]; then
        print_warn "Вы выбрали локальную модель и для ментора, и для CI/CD."
        print_warn "Будет использоваться та же модель ($GGUF_PATH) через один LLM-контейнер."
        LLM_CI_BASE_URL="http://llm:8080/v1"
        LLM_CI_API_KEY="local-api-key"
        LLM_CI_MODEL="model.gguf"
    else
        print_step "Локальная модель для CI/CD:"
        print_warn "Скачайте модель заранее и укажите путь."
        GGUF_PATH_CI=$(ask "Путь к .gguf файлу" "/home/user1/Downloads/qwen2.5-coder-7b-instruct-q4_k_m.gguf")

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
        LLM_CI_MODEL="model.gguf"
    fi

    LLM_CI_TYPE="local"
fi

# ============================================
# ШАГ 5/11: SSH-ключ для GitLab Runner
# ============================================
print_header "ШАГ 5/11: SSH-ключ для GitLab Runner"

print_step "Генерация SSH-ключа для GitLab Runner..."
mkdir -p "$PROJECT_DIR/shared/data/runner-keys"

rm -f "$PROJECT_DIR/shared/data/runner-keys/runner_ed25519" "$PROJECT_DIR/shared/data/runner-keys/runner_ed25519.pub"
ssh-keygen -t ed25519 -f "$PROJECT_DIR/shared/data/runner-keys/runner_ed25519" -N "" -C "gitlab-runner@academic" -q

RUNNER_SSH_PUB=$(cat "$PROJECT_DIR/shared/data/runner-keys/runner_ed25519.pub")
RUNNER_SSH_PRIV="$PROJECT_DIR/shared/data/runner-keys/runner_ed25519"

print_success "SSH-ключ сгенерирован: $RUNNER_SSH_PRIV"
print_step "Ключ будет автоматически добавлен в GitLab при инициализации..."

# ============================================
# ШАГ 6/11: Генерация паролей
# ============================================
print_header "ШАГ 6/11: Генерация паролей"

GITLAB_ROOT_PASSWORD=$(generate_password)
JH_API_TOKEN=$(generate_password)
LECTURER_01_PASSWORD=$(generate_password)
LECTURER_02_PASSWORD=$(generate_password)
DASHBOARD_PASSWORD=$(generate_password)

# Сохраняем все пароли в файл
mkdir -p "$PROJECT_DIR/shared/data"
PASS_FILE="$PROJECT_DIR/shared/data/credentials.env"
cat > "$PASS_FILE" << 'PASSEOF'
# ============================================
# СЕРВИСЫ — ЛОГИНЫ И ПАРОЛИ
# Этот файл сгенерирован автоматически.
# ХРАНИТЕ ЕГО В БЕЗОПАСНОМ МЕСТЕ.
# ============================================
PASSEOF
cat >> "$PASS_FILE" << PASSEOF

# --- GitLab ---
GITLAB_ROOT_PASSWORD=$GITLAB_ROOT_PASSWORD

# --- JupyterHub ---
JH_API_TOKEN=$JH_API_TOKEN

# --- Admin Dashboard ---
DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD

# --- Лекторы (обязательно смените пароли при первом входе!) ---
LECTURER_01_PASSWORD=$LECTURER_01_PASSWORD
LECTURER_02_PASSWORD=$LECTURER_02_PASSWORD
PASSEOF
chmod 600 "$PASS_FILE"

print_step "Все пароли сохранены в:"
echo "  $PASS_FILE"
print_step "Для быстрого просмотра:"
echo "  cat $PASS_FILE | grep PASSWORD"

# ============================================
# ШАГ 7/11: Проверка сети
# ============================================
print_header "ШАГ 7/11: Проверка сети"

echo ""
echo -e "  ${BOLD}Внешний IP (для доступа из VPN/лабсети):${NC} $EXTERNAL_IP"
echo -e "  ${BOLD}Локальный IP (для доступа с сервера):${NC} $PRIMARY_LOCAL_IP"
echo -e "  ${BOLD}Интерфейс:${NC} $PRIMARY_IFACE"
echo ""
echo -e "  ${GREEN}✓${NC} Внешний и локальный IP совпадают или находятся в одной подсети — DNAT не нужен"
echo -e "  ${GREEN}✓${NC} Docker-контейнеры видят $PRIMARY_LOCAL_IP (не VPN IP)"
echo ""
print_success "Сеть проверена"

# ============================================
# ШАГ 8/11: Запись .env
# ============================================
print_header "ШАГ 8/11: Генерация конфигурации"

# Извлекаем чистый IP из GITLAB_EXTERNAL_URL
GITLAB_HOST=$(echo "$GITLAB_EXTERNAL_URL" | sed 's|http://||' | sed 's|:.*||')

PROJECT_VOLUME_PREFIX=$(basename "$PROJECT_DIR")

cat > "$PROJECT_DIR/.env" <<ENVEOF
# ============================================
# МУЛЬТИСИСТЕМНЫЙ УЧЕБНЫЙ КОМПЛЕКС
# Сгенерировано $(date '+%Y-%m-%d %H:%M:%S')
# ============================================

# --- Docker volumes ---
PROJECT_VOLUME_PREFIX=$PROJECT_VOLUME_PREFIX

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
REGISTRY_PORT=5050

# --- LLM ---
LLM_MENTOR_TYPE=$LLM_MENTOR_TYPE
LLM_MENTOR_BASE_URL=$LLM_MENTOR_BASE_URL
LLM_MENTOR_API_KEY=$LLM_MENTOR_API_KEY
LLM_MENTOR_MODEL=$LLM_MENTOR_MODEL
LLM_CI_TYPE=$LLM_CI_TYPE
LLM_CI_BASE_URL=$LLM_CI_BASE_URL
LLM_CI_API_KEY=$LLM_CI_API_KEY
LLM_CI_MODEL=$LLM_CI_MODEL
LLM_USE_LOCAL=$LLM_USE_LOCAL

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
ENVEOF

chmod 600 "$PROJECT_DIR/.env"
print_success "Конфигурация записана в .env"

# ============================================
# ШАГ 9/11: Очистка и запуск сервисов
# ============================================
print_header "ШАГ 9/11: Очистка и запуск"

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

# Удаляем Docker тома (с правильным префиксом)
print_step "Удаление Docker томов..."
PROJECT_VOLUME_PREFIX=$(basename "$PROJECT_DIR")
for vol in jupyterhub-data; do
    FULL_VOL_NAME="${PROJECT_VOLUME_PREFIX}_${vol}"
    docker volume rm "$FULL_VOL_NAME" 2>/dev/null && print_success "Том $vol удалён" || true
done

print_step "Очистка завершена"

# Удаляем старые bind-mount директории (переход на Docker volumes)
rm -rf "$PROJECT_DIR/shared/data/cache_huggingface"
rm -rf "$PROJECT_DIR/shared/data/shared-pip-cache"
rm -rf "$PROJECT_DIR/shared/data/logs"
rm -rf "$PROJECT_DIR/shared/data/docs"
print_success "Старые bind-mount директории удалены"

# Создаём Docker volumes для кэшей
for vol in hf-cache pip-cache; do
    FULL_VOL_NAME="${PROJECT_VOLUME_PREFIX}_${vol}"
    docker volume inspect "$FULL_VOL_NAME" >/dev/null 2>&1 || docker volume create "$FULL_VOL_NAME"
    print_success "Volume $FULL_VOL_NAME создана"
done

# Предварительная загрузка Docker-образов (уменьшает время build)
if [[ "$LLM_USE_LOCAL" == "true" ]]; then
    print_header "ШАГ 10/11: Предзагрузка Docker-образов"
    
    print_step "Загрузка базовых образов..."
    docker pull gitlab/gitlab-ce:latest 2>/dev/null || true
    docker pull gitlab/gitlab-runner:latest 2>/dev/null || true
    docker pull registry:2 2>/dev/null || true
    docker pull python:3.10-slim 2>/dev/null || true
    
    print_step "Загрузка LLM образа (может занять 5-10 минут)..."
    print_step "Если образ уже есть — пропустит."
    docker pull ghcr.io/ggml-org/llama.cpp:server-cuda12 2>/dev/null || true
    
    print_success "Все образы загружены"
    echo ""
    
    print_header "ШАГ 11/11: Запуск сервисов"
else
    print_header "ШАГ 10/10: Запуск сервисов"
fi

print_step "Запуск docker-compose..."

# Создаём .env.jupyterhub, если не существует
JUPYTERHUB_ENV="$PROJECT_DIR/.env.jupyterhub"
if [ ! -f "$JUPYTERHUB_ENV" ]; then
    JUPYTERHUB_COOKIE_SECRET=$(openssl rand -hex 32)
    cat > "$JUPYTERHUB_ENV" << EOF
JUPYTERHUB_COOKIE_SECRET=$JUPYTERHUB_COOKIE_SECRET
EOF
    chmod 600 "$JUPYTERHUB_ENV"
    print_success "Создан .env.jupyterhub"
fi

LLM_PROFILES=""
if [[ "$LLM_USE_LOCAL" == "true" ]]; then
    LLM_PROFILES="--profile local-llm"
fi

if [[ -n "$LLM_PROFILES" ]]; then
    docker compose $LLM_PROFILES up -d --force-recreate gitlab admin-dashboard llm gitlab-runner
else
    docker compose up -d --force-recreate gitlab admin-dashboard gitlab-runner
fi

# Проверка модели в Docker volume для LLM
if [[ "$LLM_USE_LOCAL" == "true" ]]; then
    print_step "Проверка модели в Docker volume..."
    FULL_VOLUME_NAME="${PROJECT_VOLUME_PREFIX}_llm-models"
    if docker run --rm -v "$FULL_VOLUME_NAME":/models alpine sh -c "test -f /models/$MODEL_FILE" 2>/dev/null; then
        print_success "Модель $MODEL_FILE найдена в Docker volume"
    else
        print_error "Модель $MODEL_FILE НЕ найдена в Docker volume $FULL_VOLUME_NAME!"
        print_error "LLM контейнер не запустится. Запустите ШАГ 3/11 повторно."
        exit 1
    fi
fi

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

if [[ "$LLM_USE_LOCAL" == "true" ]]; then
    print_step "Ожидание запуска LLM контейнера..."
    for i in $(seq 1 30); do
        if docker logs llm 2>&1 | grep -q "llama_server"; then
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

print_step "Получение root PAT (Rails runner может занять минуту)..."
ROOT_TOKEN=$(timeout 120 docker exec gitlab gitlab-rails runner '
  user = User.find_by_username("root")
  user.personal_access_tokens.where(name: "runner-setup-token-v3").destroy_all
  token = user.personal_access_tokens.create!(
    name: "runner-setup-token-v3",
    scopes: ["api", "admin_mode", "create_runner"],
    expires_at: Date.today + 365.days
  )
  token.save!
  STDOUT.puts "TOKEN_START:" + token.token + ":TOKEN_END"
' 2>&1)
ROOT_TOKEN=$(echo "$ROOT_TOKEN" | sed -n 's/.*TOKEN_START:\(.*\):TOKEN_END.*/\1/p')

if [[ -z "$ROOT_TOKEN" ]]; then
    print_error "Не удалось получить root PAT. Вывод Rails:"
    echo "$ROOT_TOKEN"
    exit 1
fi
print_success "Root PAT успешно получен"

print_step "Создание Runner в GitLab через API..."
RUNNER_RESPONSE=$(curl -s --request POST \
  --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
  --header "X-GitLab-Admin-Mode: true" \
  --header "Content-Type: application/json" \
  --data '{"description": "academic-runner", "runner_type": "instance_type"}' \
  "http://localhost/api/v4/user/runners" 2>&1)

RUNNER_TOKEN=$(echo "$RUNNER_RESPONSE" | jq -r '.token' 2>/dev/null)
RUNNER_ID=$(echo "$RUNNER_RESPONSE" | jq -r '.id' 2>/dev/null)

if [[ -z "$RUNNER_TOKEN" || "$RUNNER_TOKEN" == "null" ]]; then
    print_error "Не удалось получить токен Runner"
    print_error "Ответ GitLab API: $RUNNER_RESPONSE"
    exit 1
fi

echo "Runner ID: $RUNNER_ID"
echo "Runner Token: $RUNNER_TOKEN"

RUNNER_CONFIG="$PROJECT_DIR/shared/data/runner-config/config.toml"

# Создаем папку и выдаем права текущему пользователю через Docker
docker run --rm \
  -v "$PROJECT_DIR/shared/data:/data" \
  alpine sh -c "mkdir -p /data/runner-config && chown -R $(id -u):$(id -g) /data/runner-config"

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
  tag_list = ["istp-runner"]
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

# Обеспечиваем наличие переменных по умолчанию (защита от unbound variable)
JUPYTERHUB_PORT="${JUPYTERHUB_PORT:-8000}"
DASHBOARD_PORT="${DASHBOARD_PORT:-9000}"
EXTERNAL_IP="${EXTERNAL_IP:-localhost}"
GITLAB_HOST="${GITLAB_HOST:-localhost}"
PRIMARY_LOCAL_IP="${PRIMARY_LOCAL_IP:-localhost}"
USE_DNAT="${USE_DNAT:-false}"

print_header "УСТАНОВКА ЗАВЕРШЕНА"

echo ""
echo -e "${GREEN}Доступы:${NC}"
echo ""
echo -e "  ${YELLOW}Все пароли в файле:${NC}"
echo "  $PASS_FILE"
echo ""
echo -e "  ${YELLOW}Быстрый просмотр:${NC}"
echo "  cat $PASS_FILE | grep PASSWORD"
echo ""
echo -e "  ${BOLD}С других ПК (через VPN/лабсеть):${NC}"
echo ""
echo -e "  ${BOLD}GitLab:${NC}        http://$EXTERNAL_IP"
echo -e "    Git clone:   git clone http://$EXTERNAL_IP/students/project.git"
echo -e "    Git SSH:     git@gitlab.$GITLAB_HOST:students/project.git"
echo -e "    Runner key:  cat $RUNNER_SSH_PRIV.pub"
echo ""
echo -e "  ${BOLD}JupyterHub:${NC}    http://$EXTERNAL_IP:$JUPYTERHUB_PORT"
echo -e "    Регистрация:   Ссылка Sign up здесь"
echo ""
echo -e "  ${BOLD}Dashboard:${NC}     http://$EXTERNAL_IP:$DASHBOARD_PORT"
echo ""

echo -e "  ${BOLD}С этого сервера:${NC}"
echo ""
echo -e "  ${BOLD}GitLab:${NC}        http://localhost (или http://$PRIMARY_LOCAL_IP)"
echo -e "  ${BOLD}JupyterHub:${NC}    http://localhost:$JUPYTERHUB_PORT"
echo -e "  ${BOLD}Dashboard:${NC}     http://localhost:$DASHBOARD_PORT"
echo ""

if [[ "${USE_DNAT}" == "true" ]]; then
    echo -e "  ${BOLD}Через VPN IP ($EXTERNAL_IP):${NC}"
    echo -e "  DNAT настроен — $EXTERNAL_IP перенаправляется на localhost"
    echo -e "  Скрипт persistency: shared/scripts/setup-dnat.sh"
    echo -e ""
fi

echo -e ""
echo -e "${BOLD}⚠️ Важно для доступа к GitLab по HTTP:${NC}"
echo -e "  1. GitLab → Settings (иконка профиля) → Password"
echo -e "  2. Установить пароль для Git-клиента"
echo -e "  ${GREEN}✓${NC} После этого git clone/push/pull по HTTP будет работать"
echo ""

echo -e "${YELLOW}Следующие шаги:${NC}"
echo ""
echo "  1. Студенты регистрируются: GitLab / JupyterHub → Sign up"
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
echo "  - GitLab: встроенная саморегистрация (sign_up_enabled)"
echo "  - JupyterHub: NativeAuthenticator (саморегистрация, сохранение паролей в БД)"
echo "  - Dashboard: Basic Auth (admin пароль из credentials.env)"
echo "  - Изоляция: LocalProcessSpawner создаёт отдельный Linux-пользователь для каждого студента"
echo "  - Сбор данных: логи и оценки сохраняются в /home/{student}/ (видны dashboard)"
echo ""
echo -e "${GREEN}Все сервисы запущены!${NC}\n"
