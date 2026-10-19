"""OpenAI-совместимый сервер эмбеддингов (sentence-transformers, CPU).

Эндпоинты:
  GET  /v1/models      — список моделей
  POST /v1/embeddings  — эмбеддинги (формат ответа как у OpenAI)
  GET  /health         — проверка здоровья

Модель загружается при старте и кешируется в памяти.
"""

import os
import time

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from sentence_transformers import SentenceTransformer

MODEL_NAME = os.environ.get(
    "EMBEDDINGS_MODEL",
    "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
)
MAX_SEQ_LENGTH = 512
BATCH_SIZE = 32

app = FastAPI(title="ISTP Embeddings Server")

_model = None


def get_model():
    global _model
    if _model is None:
        t0 = time.time()
        print(f"[embeddings] Loading model: {MODEL_NAME}", flush=True)
        _model = SentenceTransformer(MODEL_NAME)
        print(f"[embeddings] Model loaded in {time.time() - t0:.1f}s", flush=True)
    return _model


class EmbeddingRequest(BaseModel):
    model: str | None = None
    input: str | list[str] = Field(...)
    encoding_format: str | None = None


class EmbeddingItem(BaseModel):
    object: str = "embedding"
    index: int
    embedding: list[float]


class EmbeddingResponse(BaseModel):
    object: str = "list"
    data: list[EmbeddingItem]
    model: str
    usage: dict


@app.get("/health")
def health():
    return {"status": "ok", "model": MODEL_NAME, "ready": _model is not None}


@app.get("/v1/models")
def models():
    return {
        "object": "list",
        "data": [
            {
                "id": MODEL_NAME,
                "object": "model",
                "owned_by": "istp",
            }
        ],
    }


@app.post("/v1/embeddings", response_model=EmbeddingResponse)
def embeddings(req: EmbeddingRequest):
    if isinstance(req.input, str):
        texts = [req.input]
    else:
        texts = list(req.input)
    if not texts:
        raise HTTPException(status_code=400, detail="input must not be empty")
    model = get_model()
    vectors = model.encode(
        texts,
        batch_size=BATCH_SIZE,
        normalize_embeddings=False,
        show_progress_bar=False,
        convert_to_numpy=True,
    )
    data = [
        EmbeddingItem(index=i, embedding=[float(x) for x in vec])
        for i, vec in enumerate(vectors)
    ]
    return EmbeddingResponse(
        data=data,
        model=MODEL_NAME,
        usage={"prompt_tokens": 0, "total_tokens": 0},
    )
