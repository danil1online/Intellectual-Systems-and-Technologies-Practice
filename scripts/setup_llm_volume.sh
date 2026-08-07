#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Инициализация LLM volume
# Копирует модель из shared/data/llm-models в Docker volume
# Сравнивает файлы по SHA256-хешу
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

source .env

MODEL_FILE="${LLM_MODEL_NAME:-Qwen3.5-4B-Q4_K_S.gguf}"
SOURCE_DIR="$PROJECT_DIR/shared/data/llm-models"

echo "=== LLM Volume Initialization ==="
echo "Source directory: $SOURCE_DIR"
echo "Model file: $MODEL_FILE"

# Проверяем наличие модели в source
if [[ ! -f "$SOURCE_DIR/$MODEL_FILE" ]]; then
    echo "ERROR: Model not found at $SOURCE_DIR/$MODEL_FILE"
    exit 1
fi

# Создаём volume если не существует
if ! docker volume inspect llm-models >/dev/null 2>&1; then
    echo "Creating volume llm-models..."
    docker volume create llm-models
    echo "✓ Volume created"
fi

# Сравниваем хеши
SOURCE_HASH=$(sha256sum "$SOURCE_DIR/$MODEL_FILE" | cut -d' ' -f1)
VOLUME_HASH=$(docker run --rm -v llm-models:/models alpine sh -c "sha256sum /models/$MODEL_FILE | cut -d' ' -f1" 2>/dev/null || echo "")

if [[ -n "$VOLUME_HASH" && "$VOLUME_HASH" == "$SOURCE_HASH" ]]; then
    echo "✓ Model already in Docker volume (identical)"
else
    echo "Copying model to Docker volume..."
    docker run --rm \
        -v llm-models:/models \
        -v "$SOURCE_DIR":/source:ro \
        alpine sh -c "cp /source/$MODEL_FILE /models/"
    
    NEW_HASH=$(docker run --rm -v llm-models:/models alpine sh -c "sha256sum /models/$MODEL_FILE | cut -d' ' -f1" 2>/dev/null)
    if [[ "$NEW_HASH" == "$SOURCE_HASH" ]]; then
        echo "✓ Model successfully written to Docker volume"
    else
        echo "ERROR: Failed to write model to Docker volume"
        exit 1
    fi
fi
