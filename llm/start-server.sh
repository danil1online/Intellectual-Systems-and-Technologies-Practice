#!/bin/bash
set -e

MODEL_PATH="${GGUF_MODEL_PATH:-/models/Qwen3.5-0.8B-Q4_K_M.gguf}"
NGPU_LAYERS="${NGPU_LAYERS:-99}"
CONTEXT_SIZE="${CONTEXT_SIZE:-32768}"
HOST="${LLM_HOST:-0.0.0.0}"
PORT="${LLM_PORT:-8080}"

# Проверяем наличие модели
if [ ! -f "$MODEL_PATH" ]; then
    # Проверяем альтернативные пути
    BASENAME=$(basename "$MODEL_PATH")
    if [ -f "/models/$BASENAME" ]; then
        MODEL_PATH="/models/$BASENAME"
    elif [ -f "$BASENAME" ]; then
        MODEL_PATH="$BASENAME"
    else
        echo "ERROR: Model not found at $MODEL_PATH"
        echo "Available in /models/:"
        ls -la /models/ 2>/dev/null || echo "No /models/ directory"
        exit 1
    fi
fi

echo "Starting llama-server with:"
echo "  Model: $MODEL_PATH"
echo "  GPU Layers: $NGPU_LAYERS"
echo "  Context: $CONTEXT_SIZE"
echo "  Host: $HOST"
echo "  Port: $PORT"

exec /app/llama-server \
    -m "$MODEL_PATH" \
    -ngl "$NGPU_LAYERS" \
    -c "$CONTEXT_SIZE" \
    --host "$HOST" \
    --port "$PORT" \
    --ctx-size "$CONTEXT_SIZE" \
    --cache-type-k q8_0 \
    --cache-type-v q8_0
