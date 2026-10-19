FROM python:3.10-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HF_HOME=/models/hf

WORKDIR /app

COPY app.py .

RUN pip install --upgrade pip && \
    pip install "fastapi==0.115.*" "uvicorn[standard]==0.30.*" "sentence-transformers==3.4.*"

# Модель скачивается при сборке образа (нужен доступ к HuggingFace),
# в рантайме интернет не требуется.
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2')"

EXPOSE 8021

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8021"]
