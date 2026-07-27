#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Инициализация LLM volume
# Копирует модель из shared/data/llm-models в Docker volume
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

source .env

MODEL_FILE="${LLM_MODEL_NAME:-Qwen3.5-0.8B-Q4_K_M.gguf}"
SOURCE_DIR="$PROJECT_DIR/shared/data/llm-models"

echo "=== LLM Volume Initialization ==="
echo "Source directory: $SOURCE_DIR"
echo "Model file: $MODEL_FILE"

# Проверяем наличие модели в source
if [[ ! -f "$SOURCE_DIR/$MODEL_FILE" ]]; then
    echo "ERROR: Model not found at $SOURCE_DIR/$MODEL_FILE"
    echo ""
    echo "Please place the model file in: $SOURCE_DIR/"
    echo "Or run setup.sh to download and copy the model."
    exit 1
fi

# Создаём volume если не существует
if ! docker volume inspect llm-models >/dev/null 2>&1; then
    echo "Creating volume llm-models..."
    docker volume create llm-models
    echo "✓ Volume created"
fi

# Копируем модель в volume
echo "Copying model to Docker volume..."
docker run --rm \
    -v llm-models:/models \
    -v "$SOURCE_DIR":/source:ro \
    alpine sh -c "cp /source/$MODEL_FILE /models/"

# Проверяем результат
if docker run --rm -v llm-models:/models alpine sh -c "test -f /models/$MODEL_FILE" 2>/dev/null; then
    echo "✓ Model successfully written to Docker volume"
    echo ""
    echo "The model is now independent of the original file."
    echo "You can safely delete: $SOURCE_DIR/$MODEL_FILE (if desired)"
else
    echo "ERROR: Failed to write model to Docker volume"
    exit 1
fi
