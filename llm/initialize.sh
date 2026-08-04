#!/bin/bash
set -e

MODEL_NAME="model.gguf"
SOURCE_PATH="${LLM_SOURCE_PATH:-/source}"
MODEL_DIR="/models"

echo "=== LLM Model Initialization ==="
echo "Model name: $MODEL_NAME"
echo "Source path: $SOURCE_PATH"
echo "Model dir: $MODEL_DIR"

# Проверяем, есть ли модель в volume
if [ -f "$MODEL_DIR/$MODEL_NAME" ]; then
    echo "✓ Model already exists in volume: $MODEL_DIR/$MODEL_NAME"
else
    # Копируем модель из source path
    if [ -f "$SOURCE_PATH/$MODEL_NAME" ]; then
        echo "Copying model from $SOURCE_PATH/$MODEL_NAME to $MODEL_DIR/$MODEL_NAME..."
        cp "$SOURCE_PATH/$MODEL_NAME" "$MODEL_DIR/$MODEL_NAME"
        echo "✓ Model copied successfully"
    else
        echo "ERROR: Model not found at $SOURCE_PATH/$MODEL_NAME"
        exit 1
    fi
fi

echo ""
echo "Starting llama-server..."

# Запускаем llama-server
exec /app/llama-server \
    -m "$MODEL_DIR/$MODEL_NAME" \
    -ngl "${NGPU_LAYERS:-99}" \
    -c "${CONTEXT_SIZE:-32768}" \
    --host "${LLM_HOST:-0.0.0.0}" \
    --port "${LLM_PORT:-8080}" \
    --ctx-size "${CONTEXT_SIZE:-32768}" \
    --cache-type-k q8_0 \
    --cache-type-v q8_0
