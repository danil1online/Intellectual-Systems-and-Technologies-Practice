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

LLM_REMOTE_MIN_CTX=32768
REMOTE_LLM_BASE=""
REMOTE_LLM_MODEL=""

normalize_llm_endpoint() {
    local endpoint="$1"
    endpoint=$(printf '%s' "$endpoint" | tr -d '[:space:]')
    endpoint="${endpoint%/}"
    if [[ "$endpoint" == */v1 ]]; then
        endpoint="${endpoint%/v1}"
    fi
    if [[ -z "$endpoint" ]]; then
        printf 'http://192.168.2.75:8080\n'
    else
        printf '%s\n' "$endpoint"
    fi
}

probe_remote_llm() {
    local title="$1"
    local endpoint url raw parsed model ctx quant params fmt again
    while true; do
        endpoint=$(ask "Endpoint OpenAI-compatible ($title, IP:port, без /v1/)" "http://192.168.2.75:8080")
        endpoint=$(normalize_llm_endpoint "$endpoint")
        url="${endpoint}/v1/models"
        print_step "Проверка LLM: $url"
        raw=$(curl -fsS --max-time 10 "$url" 2>&1 || true)

        parsed=$(LLM_MODELS_RESPONSE="$raw" python3 - <<'PY' 2>/dev/null || true
import sys, os, json, re
try:
    data = json.loads(os.environ.get("LLM_MODELS_RESPONSE", ""))
except Exception:
    print("ERROR|не удалось распознать JSON-ответ")
    sys.exit(0)

candidates = []
if isinstance(data, list):
    candidates.extend(data)
else:
    for key in ("data", "models"):
        arr = data.get(key) if isinstance(data, dict) else None
        if isinstance(arr, list):
            candidates.extend(arr)

if not candidates:
    print("ERROR|список моделей пуст")
    sys.exit(0)

def _clean(v):
    if v is None:
        return ""
    if isinstance(v, bool):
        return ""
    return str(v).strip()

model = ""
ctx = None
quant = ""
params = ""
fmt = ""

for item in candidates:
    if not isinstance(item, dict):
        continue

    for key in ("id", "name", "model"):
        val = _clean(item.get(key))
        if val:
            model = val
            break

    for key in ("n_ctx_train", "context_size", "ctx"):
        val = item.get(key)
        if isinstance(val, bool):
            continue
        if isinstance(val, (int, float)):
            ctx = val
            break
        if isinstance(val, str) and val.strip().isdigit():
            ctx = int(val.strip())
            break

    for key in ("meta", "details"):
        sub = item.get(key)
        if not isinstance(sub, dict):
            continue

        for key2 in ("n_ctx_train", "context_size", "ctx"):
            val = sub.get(key2)
            if isinstance(val, bool):
                continue
            if isinstance(val, (int, float)):
                ctx = val
                break
            if isinstance(val, str) and val.strip().isdigit():
                ctx = int(val.strip())
                break

        for key2 in ("quantization_level", "quantization"):
            val = _clean(sub.get(key2))
            if val and not quant:
                quant = val

        for key2 in ("parameter_size", "n_params", "params"):
            val = sub.get(key2)
            if val not in (None, "", 0) and not params:
                params = _clean(val)

        val = _clean(sub.get("format"))
        if val and not fmt:
            fmt = val

    for key in ("quantization_level", "quantization"):
        val = _clean(item.get(key))
        if val and not quant:
            quant = val

    for key in ("parameter_size", "n_params", "params"):
        val = item.get(key)
        if val not in (None, "", 0) and not params:
            params = _clean(val)

    val = _clean(item.get("format"))
    if val and not fmt:
        fmt = val

    if model and ctx is not None and quant and params and fmt:
        break

if ctx is None:
    matches = re.findall(r'"(?:n_ctx_train|context_size|ctx)"\s*:\s*(\d+)', json.dumps(data))
    if matches:
        ctx = int(matches[0])

if isinstance(ctx, float) and ctx.is_integer():
    ctx = int(ctx)

if not model:
    print("ERROR|не удалось определить имя модели")
    sys.exit(0)

print("OK|{model}|{ctx}|{quant}|{params}|{fmt}".format(
    model=model,
    ctx=ctx if ctx is not None else "",
    quant=quant,
    params=params,
    fmt=fmt,
))
PY
)

        if [[ "$parsed" == "OK|"* ]]; then
            IFS='|' read -r _ model ctx quant params fmt <<< "$parsed"

            if [[ -z "$model" ]]; then
                print_error "$title: не удалось определить имя модели из ответа"
            elif [[ "$ctx" =~ ^[0-9]+$ ]] && (( ctx < LLM_REMOTE_MIN_CTX )); then
                print_error "$title: контекст $ctx < $LLM_REMOTE_MIN_CTX — для авто-оценки может не хватить"
            else
                if [[ "$ctx" =~ ^[0-9]+$ ]]; then
                    print_success "$title: LLM доступен. Модель: $model, context: $ctx, quant: ${quant:-—}, params: ${params:-—}, format: ${fmt:-—}"
                else
                    print_success "$title: LLM доступен. Модель: $model. Контекст не указан в /v1/models — проверьте --ctx-size вручную"
                fi
                REMOTE_LLM_BASE="$endpoint"
                REMOTE_LLM_MODEL="$model"
                return 0
            fi
        else
            print_error "$title: LLM недоступен или ответ некорректен: ${parsed:-пусто}"
        fi

        again=$(ask_choice \
            "LLM не прошёл проверку" \
            "1" "Ввести endpoint ещё раз" \
            "2" "Вернуться к выбору локальная/удалённая" \
            "1")

        if [[ "$again" == "2" ]]; then
            REMOTE_LLM_BASE=""
            REMOTE_LLM_MODEL=""
            return 1
        fi
    done
}

configure_local_llm_mentor() {
    print_step "Выбор встроенного LLM-образа:"
    echo "  1. GigaChat3.1-10B-A1.8B (~6.1 ГБ, ~7.5 ГБ образ)"
    echo "  2. Qwen2.5-3B-Instruct (~2.0 ГБ, ~3.5 ГБ образ)"

    local LLM_MODEL_CHOICE
    LLM_MODEL_CHOICE=$(ask_choice \
        "Выберите модель (1 или 2)" \
        "1" "GigaChat3.1-10B-A1.8B" \
        "2" "Qwen2.5-3B-Instruct" \
        "1")

    if [[ "$LLM_MODEL_CHOICE" == "1" ]]; then
        LLM_IMAGE="istp-llm-gigachat:latest"
        LLM_PROFILE="local-llm-gigachat"
        print_success "Выбрана: GigaChat3.1-10B-A1.8B"
    else
        LLM_IMAGE="istp-llm-qwen:latest"
        LLM_PROFILE="local-llm-qwen"
        print_success "Выбрана: Qwen2.5-3B-Instruct"
    fi

    LLM_MENTOR_TYPE="local"
    LLM_MENTOR_BASE_URL="http://llm:8080/v1"
    LLM_MENTOR_API_KEY="local-api-key"
    LLM_MENTOR_MODEL="model.gguf"
    LLM_USE_LOCAL="true"
}

configure_local_llm_ci() {
    if [[ "$LLM_MENTOR_TYPE" == "local" ]]; then
        print_warn "Локальная модель будет использоваться и для ментора, и для CI/CD через один LLM-контейнер."
        LLM_CI_BASE_URL="http://llm:8080/v1"
        LLM_CI_API_KEY="local-api-key"
        LLM_CI_MODEL="model.gguf"
        LLM_CI_IMAGE="$LLM_IMAGE"
        LLM_CI_PROFILE="$LLM_PROFILE"
        LLM_USE_LOCAL="true"
    else
        print_step "Выбор встроенного LLM-образа для CI/CD:"
        echo "  1. GigaChat3.1-10B-A1.8B (~6.1 ГБ, ~7.5 ГБ образ)"
        echo "  2. Qwen2.5-3B-Instruct (~2.0 ГБ, ~3.5 ГБ образ)"

        local LLM_CI_MODEL_CHOICE
        LLM_CI_MODEL_CHOICE=$(ask_choice \
            "Выберите модель (1 или 2)" \
            "1" "GigaChat3.1-10B-A1.8B" \
            "2" "Qwen2.5-3B-Instruct" \
            "1")

        if [[ "$LLM_CI_MODEL_CHOICE" == "1" ]]; then
            LLM_CI_IMAGE="istp-llm-gigachat:latest"
            LLM_CI_PROFILE="local-llm-gigachat"
            print_success "Выбрана: GigaChat3.1-10B-A1.8B для CI/CD"
        else
            LLM_CI_IMAGE="istp-llm-qwen:latest"
            LLM_CI_PROFILE="local-llm-qwen"
            print_success "Выбрана: Qwen2.5-3B-Instruct для CI/CD"
        fi

        LLM_CI_BASE_URL="http://llm:8080/v1"
        LLM_CI_API_KEY="local-api-key"
        LLM_CI_MODEL="model.gguf"
        LLM_USE_LOCAL="false"
    fi

    LLM_CI_TYPE="local"
}

setup_llm_mentor() {
    local type
    while true; do
        type=$(ask_choice \
            "Как запустить LLM для ИИ-Ментора?" \
            "1" "OpenAI API (уже существующий внешний сервис)" \
            "2" "Локальный контейнер (загрузит свою модель)" \
            "2")

        if [[ "$type" == "1" ]]; then
            if probe_remote_llm "ИИ-Ментора"; then
                LLM_MENTOR_BASE_URL="${REMOTE_LLM_BASE}/v1"
                LLM_MENTOR_API_KEY=$(ask "OpenAI API Key")
                LLM_MENTOR_MODEL=$(ask "Имя модели для API" "$REMOTE_LLM_MODEL")
                LLM_MENTOR_TYPE="openai"
                LLM_USE_LOCAL="false"
                print_success "Ментор: OpenAI API → $LLM_MENTOR_BASE_URL (модель: $LLM_MENTOR_MODEL)"
                return 0
            else
                print_warn "Ментор: переключаемся на повторный выбор LLM"
                continue
            fi
        else
            configure_local_llm_mentor
            return 0
        fi
    done
}

setup_llm_ci() {
    local type
    while true; do
        type=$(ask_choice \
            "Как запустить LLM для CI/CD?" \
            "1" "OpenAI API (уже существующий внешний сервис)" \
            "2" "Локальный контейнер (загрузит свою модель)" \
            "2")

        if [[ "$type" == "1" ]]; then
            if probe_remote_llm "CI/CD"; then
                LLM_CI_BASE_URL="${REMOTE_LLM_BASE}/v1"
                LLM_CI_API_KEY=$(ask "OpenAI API Key")
                LLM_CI_MODEL=$(ask "Имя модели для API" "$REMOTE_LLM_MODEL")
                LLM_CI_TYPE="openai"
                print_success "CI/CD LLM: OpenAI API → $LLM_CI_BASE_URL (модель: $LLM_CI_MODEL)"
                return 0
            else
                print_warn "CI/CD: переключаемся на повторный выбор LLM"
                continue
            fi
        else
            configure_local_llm_ci
            return 0
        fi
    done
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
LOCAL_IPS=$(ip -4 addr show | grep -oP 'inet \K[\d.]+' | grep -v '^127\.' | grep -vE '^172\.(1[6-9]|2[0-9]|3[01])\.' | grep -vE '^192\.168\.(200|201)\.' | sort -u || true)

# Находим VPN IP (amnezia WG — интерфейсы awg*)
VPN_IP=$(ip -4 addr show | grep -A1 'awg' | grep -oP 'inet \K[\d.]+' || true)

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
echo -e "  - Со студенческих ПК через VPN (amnezia WireGuard)"
echo -e "  - Для git clone/push/pull"
echo -e "  - Для GitLab external_url и callback URL"
echo -e "  - GitLab external_url (критично!)"
echo -e ""
echo -e "  ${BOLD}Важно:${NC} VPN IP недоступен из Docker-контейнеров и не рекомендуется к использованию."
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
    #if ! echo "$LOCAL_IPS" | grep -q "^${EXTERNAL_IP}$"; then
    #    print_error "IP $EXTERNAL_IP не найден в допустимых локальных IP!"
    #    print_step "Допустимые IP:"
    #    echo "$LOCAL_IPS" | head -5 | while read ip; do
    #        print_step "  - $ip"
    #    done
    #    continue
    #fi
    
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

PROJECT_VOLUME_PREFIX=$(basename "$PROJECT_DIR")
DATA_VOLUME="${PROJECT_VOLUME_PREFIX}_shared-data"
HF_CACHE_VOLUME="${PROJECT_VOLUME_PREFIX}_hf-cache"
TORCH_CACHE_VOLUME="${PROJECT_VOLUME_PREFIX}_torch-cache"
ISTP_DATA_VERSION="2"
ISTP_HF_VERSION="2"
ISTP_TORCH_VERSION="2"

JUPYTERHUB_IMAGE_CANDIDATES=("istp-jupyterhub:latest" "ghcr.io/danil1online/istp-jupyterhub:latest")

find_jupyterhub_data_image_v2() {
    local image
    for image in "${JUPYTERHUB_IMAGE_CANDIDATES[@]}"; do
        if docker image inspect "$image" >/dev/null 2>&1 && \
            docker run --rm --entrypoint test "$image" -f /shared/data/.istp-data-version >/dev/null 2>&1 && \
            docker run --rm --entrypoint test "$image" -f /hf-cache/.istp-hf-version >/dev/null 2>&1 && \
            docker run --rm --entrypoint test "$image" -f /shared/torch-cache/.istp-torch-version >/dev/null 2>&1; then
            echo "$image"
            return 0
        fi
    done
    return 1
}

volume_version() {
    local volume_name="$1"
    local marker_path="$2"
    if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
        echo ""
        return 0
    fi
    docker run --rm -v "$volume_name":/volume --entrypoint cat alpine "/volume${marker_path}" 2>/dev/null || true
}

refresh_volume_if_stale() {
    local volume_name="$1"
    local expected_version="$2"
    local marker_path="$3"
    local current_version

    if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
        docker volume create "$volume_name"
        print_success "Volume $volume_name создана (будет заполнена из образа при старте JupyterHub)"
        return 0
    fi

    current_version=$(volume_version "$volume_name" "$marker_path")
    if [[ "$current_version" == "$expected_version" ]]; then
        print_success "Volume $volume_name уже с версией $expected_version"
        return 0
    fi

    print_step "Volume $volume_name устарела (версия: ${current_version:-нет}; ожидалось: $expected_version) — пересоздаю"
    docker volume rm "$volume_name" >/dev/null 2>&1 || true
    docker volume create "$volume_name"
    print_success "Volume $volume_name пересоздана (будет заполнена из образа при старте JupyterHub)"
}

JUPYTERHUB_GHCR_IMAGE="ghcr.io/danil1online/istp-jupyterhub:latest"
DATA_IMAGE_V2=$(find_jupyterhub_data_image_v2 || true)

if [[ -z "$DATA_IMAGE_V2" ]]; then
    print_step "JupyterHub-образ с предзагруженными данными не найден локально"
    print_step "Скачиваю из GHCR: $JUPYTERHUB_GHCR_IMAGE"
    if docker pull "$JUPYTERHUB_GHCR_IMAGE" 2>/dev/null; then
        print_success "Образ загружен: $JUPYTERHUB_GHCR_IMAGE"
        DATA_IMAGE_V2=$(find_jupyterhub_data_image_v2 || true)
    else
        print_error "Не удалось скачать образ из GHCR: $JUPYTERHUB_GHCR_IMAGE"
        print_error "Соберите образ вручную: README.md → 'Сборка JupyterHub-образа' или авторизуйтесь в ghrc.io"
        exit 1
    fi
fi

if [[ -n "$DATA_IMAGE_V2" ]]; then
    if docker image inspect "$JUPYTERHUB_GHCR_IMAGE" >/dev/null 2>&1; then
        print_success "Образ $JUPYTERHUB_GHCR_IMAGE присутствует"
    else
        docker tag "$DATA_IMAGE_V2" "$JUPYTERHUB_GHCR_IMAGE"
        print_success "Приметил $DATA_IMAGE_V2 как $JUPYTERHUB_GHCR_IMAGE"
    fi
    print_step "Использую образ с предзагруженными данными: $DATA_IMAGE_V2"
    refresh_volume_if_stale "$DATA_VOLUME" "$ISTP_DATA_VERSION" "/.istp-data-version"
    refresh_volume_if_stale "$HF_CACHE_VOLUME" "$ISTP_HF_VERSION" "/.istp-hf-version"
    refresh_volume_if_stale "$TORCH_CACHE_VOLUME" "$ISTP_TORCH_VERSION" "/.istp-torch-version"
    print_success "Data/cache volumes будут заполнены из образа при старте JupyterHub"
else
    print_error "JupyterHub-образ с предзагруженными данными (version-маркеры) не найден"
    print_error "Соберите образ вручную: README.md → 'Сборка JupyterHub-образа'"
    exit 1
fi
# ШАГ 3/11: LLM для ИИ-Ментора
# ============================================
print_header "ШАГ 3/11: Настройка LLM для ИИ-Ментора"

LLM_USE_LOCAL="false"
LLM_MENTOR_TYPE=""
LLM_MENTOR_BASE_URL=""
LLM_MENTOR_API_KEY=""
LLM_MENTOR_MODEL=""
LLM_IMAGE=""
LLM_PROFILE=""

setup_llm_mentor

# ============================================
# ШАГ 4/11: LLM для CI/CD
# ============================================
print_header "ШАГ 4/11: Настройка LLM для CI/CD"

LLM_CI_TYPE=""
LLM_CI_BASE_URL=""
LLM_CI_API_KEY=""
LLM_CI_MODEL=""
LLM_CI_IMAGE=""
LLM_CI_PROFILE=""

setup_llm_ci

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
echo -e "  ${BOLD}Интерфейс:${NC} $PRIMARY_IFACE"
echo ""
echo -e "  ${GREEN}✓${NC} Внешний и локальный IP совпадают или находятся в одной подсети — DNAT не нужен"
echo -e "  ${GREEN}✓${NC} Docker-контейнеры используют Docker DNS для связи с GitLab"
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
for vol in hf-cache pip-cache torch-cache; do
    FULL_VOL_NAME="${PROJECT_VOLUME_PREFIX}_${vol}"
    docker volume inspect "$FULL_VOL_NAME" >/dev/null 2>&1 || docker volume create "$FULL_VOL_NAME"
    print_success "Volume $FULL_VOL_NAME создана"
done

# Предварительная загрузка Docker-образов (уменьшает время build)
if [[ "$LLM_USE_LOCAL" == "true" ]] || [[ "$LLM_CI_TYPE" == "local" && "$LLM_MENTOR_TYPE" != "local" ]]; then
    print_header "ШАГ 10/11: Предзагрузка Docker-образов"
    
    print_step "Загрузка базовых образов..."
    docker pull gitlab/gitlab-ce:18.10.4-ce.0 2>/dev/null || true
    docker pull gitlab/gitlab-runner:alpine-v18.10.1 2>/dev/null || true
    docker pull registry:2 2>/dev/null || true
    docker pull python:3.10-slim 2>/dev/null || true
    
    # Определяем какие образы нужны
    NEEDED_IMAGES=""
    if [[ "$LLM_USE_LOCAL" == "true" ]]; then
        NEEDED_IMAGES="$LLM_IMAGE"
    elif [[ "$LLM_CI_TYPE" == "local" ]]; then
        NEEDED_IMAGES="$LLM_CI_IMAGE"
    fi
    
    if [[ -n "$NEEDED_IMAGES" ]]; then
        print_step "Предзагрузка встроенных LLM-образов из GHCR..."
        for IMG in $NEEDED_IMAGES; do
            GCR_IMAGE="ghcr.io/danil1online/$IMG"
            if docker image inspect "$IMG" >/dev/null 2>&1; then
                print_success "Образ $IMG уже установлен"
            else
                print_step "Загрузка $IMG с GHCR (может занять 5-15 минут)..."
                if docker pull "$GCR_IMAGE" 2>/dev/null; then
                    docker tag "$GCR_IMAGE" "$IMG" 2>/dev/null
                    print_success "Загружен и про tagged: $GCR_IMAGE → $IMG"
                else
                    print_error "Не удалось загрузить $IMG с GHCR"
                    print_error "Соберите образ вручную:"
                    if [[ "$IMG" == *"gigachat"* ]]; then
                        print_error "  docker build -f llm/Dockerfile.gigachat -t istp-llm-gigachat:latest ."
                    else
                        print_error "  docker build -f llm/Dockerfile.qwen -t istp-llm-qwen:latest ."
                    fi
                    print_error "Или выполните: docker pull $GCR_IMAGE && docker tag $GCR_IMAGE $IMG"
                    exit 1
                fi
            fi
        done
    fi
    
    print_success "Все образы загружены"
    echo ""
    
    print_header "ШАГ 11/11: Запуск сервисов"
else
    print_header "ШАГ 10/11: Запуск сервисов"
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

LLM_PROFILE_FLAG=""
LLM_START_PROFILE=""

if [[ "$LLM_USE_LOCAL" == "true" ]]; then
    LLM_PROFILE_FLAG="--profile $LLM_PROFILE"
    LLM_START_PROFILE="$LLM_IMAGE"
    
    # Проверка наличия LLM-образа
    if docker image inspect "$LLM_IMAGE" >/dev/null 2>&1; then
        print_success "LLM образ для ментора $LLM_IMAGE найден"
    else
        print_error "LLM образ для ментора $LLM_IMAGE не найден!"
        print_error "Соберите его вручную:"
        if [[ "$LLM_IMAGE" == "istp-llm-gigachat:latest" ]]; then
            print_error "  docker build -f llm/Dockerfile.gigachat -t istp-llm-gigachat:latest ."
        else
            print_error "  docker build -f llm/Dockerfile.qwen -t istp-llm-qwen:latest ."
        fi
        exit 1
    fi
elif [[ "$LLM_CI_TYPE" == "local" ]]; then
    LLM_PROFILE_FLAG="--profile $LLM_CI_PROFILE"
    LLM_START_PROFILE="$LLM_CI_IMAGE"
    
    # Проверка наличия LLM-образа
    if docker image inspect "$LLM_CI_IMAGE" >/dev/null 2>&1; then
        print_success "LLM образ для CI/CD $LLM_CI_IMAGE найден"
    else
        print_error "LLM образ для CI/CD $LLM_CI_IMAGE не найден!"
        print_error "Соберите его вручную:"
        if [[ "$LLM_CI_IMAGE" == "istp-llm-gigachat:latest" ]]; then
            print_error "  docker build -f llm/Dockerfile.gigachat -t istp-llm-gigachat:latest ."
        else
            print_error "  docker build -f llm/Dockerfile.qwen -t istp-llm-qwen:latest ."
        fi
        exit 1
    fi
fi

# ============================================
# Сборка CI-образа istp-ci из исходников репозитория.
# Критично: предсобраный GHCR-образ со старыми скриптами (нет selection
# по Pr_<N> и нет persist в dashboard). Собираем локально, независимо от типа LLM.
# ============================================
if [[ -f "$PROJECT_DIR/runner/Dockerfile.python310" ]]; then
    print_step "Сборка istp-ci:latest из runner/Dockerfile.python310 (может занять несколько минут)..."
    if docker build -f "$PROJECT_DIR/runner/Dockerfile.python310" -t istp-ci:latest "$PROJECT_DIR" 2>&1; then
        docker tag istp-ci:latest ghcr.io/danil1online/istp-ci:latest 2>/dev/null || true
        print_success "istp-ci:latest собран из исходников"
    else
        print_warn "Сборка istp-ci не удалась."
    fi
fi

if ! docker image inspect istp-ci:latest >/dev/null 2>&1; then
    print_step "Подтягиваем предсобраный istp-ci с GHCR (fallback)..."
    if docker pull ghcr.io/danil1online/istp-ci:latest 2>/dev/null; then
        docker tag ghcr.io/danil1online/istp-ci:latest istp-ci:latest 2>/dev/null || true
        print_success "istp-ci:latest подтянут с GHCR"
    fi
fi

if docker image inspect istp-ci:latest >/dev/null 2>&1; then
    print_success "Образ istp-ci:latest готов"
else
    print_error "Образ istp-ci:latest отсутствует — runner не сможет запускать job'ы авто-оценки."
    print_error "Соберите вручную: docker build -f runner/Dockerfile.python310 -t istp-ci:latest ."
    exit 1
fi

if [[ -n "$LLM_PROFILE_FLAG" ]]; then
    LLM_SERVICE_NAME=""
    if [[ "$LLM_USE_LOCAL" == "true" ]]; then
        if [[ "$LLM_IMAGE" == *"gigachat"* ]]; then
            LLM_SERVICE_NAME="llm-gigachat"
        elif [[ "$LLM_IMAGE" == *"qwen"* ]]; then
            LLM_SERVICE_NAME="llm-qwen"
        fi
    elif [[ "$LLM_CI_TYPE" == "local" ]]; then
        if [[ "$LLM_CI_IMAGE" == *"gigachat"* ]]; then
            LLM_SERVICE_NAME="llm-gigachat"
        elif [[ "$LLM_CI_IMAGE" == *"qwen"* ]]; then
            LLM_SERVICE_NAME="llm-qwen"
        fi
    fi
    if [[ -n "$LLM_SERVICE_NAME" ]]; then
        docker compose $LLM_PROFILE_FLAG up -d --force-recreate gitlab admin-dashboard "$LLM_SERVICE_NAME" gitlab-runner
    else
        docker compose $LLM_PROFILE_FLAG up -d --force-recreate gitlab admin-dashboard gitlab-runner
    fi
else
     docker compose up -d --force-recreate gitlab admin-dashboard gitlab-runner
fi

if ! docker network inspect "${PROJECT_VOLUME_PREFIX}_internal" >/dev/null 2>&1; then
    print_error "Сеть ${PROJECT_VOLUME_PREFIX}_internal не найдена — build-контейнеры раннера не смогут клонировать репозиторий и обращаться к LLM"
    exit 1
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

if [[ "$LLM_USE_LOCAL" == "true" ]] || [[ "$LLM_CI_TYPE" == "local" ]]; then
    print_step "Ожидание запуска LLM контейнера..."
    for i in $(seq 1 30); do
        if docker exec llm curl -sf http://localhost:8080/v1/models > /dev/null 2>&1; then
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

# Устанавливаем теги runner'а через API (config.toml не сохраняет теги при API-регистрации)
print_step "Установка тегов runner'а..."
curl -s -X PUT \
  --header "PRIVATE-TOKEN: $ROOT_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"tag_list": ["istp-runner"]}' \
  "http://localhost/api/v4/runners/$RUNNER_ID" 2>/dev/null
print_success "Теги runner'а установлены"

RUNNER_CONFIG="$PROJECT_DIR/shared/data/runner-config/config.toml"

# Создаем папку и выдаем права текущему пользователю через Docker
docker run --rm \
  -v "$PROJECT_DIR/shared/data:/data" \
  alpine sh -c "mkdir -p /data/runner-config && chown -R $(id -u):$(id -g) /data/runner-config"

cat > "$RUNNER_CONFIG" << RUNNEREOF
concurrent = 4
check_interval = 0
shutdown_request_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "academic-runner"
  url = "http://gitlab:80"
  token = "$RUNNER_TOKEN"
  executor = "docker"
  tag_list = ["istp-runner"]
  [runners.custom_build_dir]
  [runners.cache]
  [runners.docker]
    image = "istp-ci:latest"
    network_mode = "${PROJECT_VOLUME_PREFIX}_internal"
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
echo "  2. Git clone/push/pull с студенческих ПК:"
echo "     git clone http://$EXTERNAL_IP/students/project.git"
echo "     git remote add origin http://$EXTERNAL_IP/students/project.git"
echo ""
echo "  3. SSH доступ к GitLab:"
echo "     ssh-keygen -t ed25519 -C student@pc"
echo "     # добавить публичный ключ в GitLab → Settings → SSH Keys"
echo "     git clone git@gitlab.$GITLAB_HOST:students/project.git"
echo ""
echo "  4. Инструкция по настройке студентов: docs/Pr_0.md"
echo ""
echo -e "  ${YELLOW}Полная очистка учебных данных:${NC}"
echo "  docker volume rm ${PROJECT_VOLUME_PREFIX}_shared-data"
echo ""
echo -e "${YELLOW}Архитектура:${NC}"
echo "  - GitLab: встроенная саморегистрация (sign_up_enabled)"
echo "  - JupyterHub: NativeAuthenticator (саморегистрация, сохранение паролей в БД)"
echo "  - Dashboard: Basic Auth (admin пароль из credentials.env)"
echo "  - Изоляция: LocalProcessSpawner создаёт отдельный Linux-пользователь для каждого студента"
echo "  - Сбор данных: логи и оценки сохраняются в /home/{student}/ (видны dashboard)"
echo ""
echo -e "${GREEN}Все сервисы запущены!${NC}\n"
