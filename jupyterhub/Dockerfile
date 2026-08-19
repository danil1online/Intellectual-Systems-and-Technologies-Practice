FROM python:3.10-slim

# Установка Node.js для configurable-http-proxy
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    openssh-client \
    procps \
    build-essential \
    nano \
    npm \
    nodejs \
    libeigen3-dev \
    ffmpeg \
    libsndfile1 \
    libglib2.0-0 \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Установка configurable-http-proxy
RUN npm install -g configurable-http-proxy

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_USER=0
ENV PIP_NO_CACHE_DIR=1
ENV C_INCLUDE_PATH=/usr/include/eigen3
ENV CPLUS_INCLUDE_PATH=/usr/include/eigen3
ENV HF_HOME=/hf-cache
ENV HF_HUB_CACHE=/hf-cache/hub
ENV HF_DATASETS_CACHE=/hf-cache/datasets
ENV HF_TRANSFORMERS_CACHE=/hf-cache/transformers
ENV TRANSFORMERS_CACHE=/hf-cache/transformers
ENV XDG_CACHE_HOME=/hf-cache/xdg-cache
ENV TORCH_HOME=/shared/torch-cache
ENV NLTK_DATA=/usr/share/nltk_data

# Установка Python пакетов
RUN pip install --no-cache-dir \
    jupyterhub==4.1.6 \
    jupyterlab==4.3.4 \
    notebook==7.3.2 \
    jupyterhub-nativeauthenticator \
    jupyter-ai==2.31.7 \
    jupyter-ai-magics==2.31.7 \
    langchain-openai==0.2.14 \
    langchain-ollama==0.2.2 \
    ipywidgets==8.1.5 \
    anywidget==0.9.15 \
    requests==2.32.3 \
    traitlets==5.14.3 \
    aiohttp==3.11.11 \
    nbconvert[webpdf]

# ML-библиотеки (CPU-only PyTorch)
RUN pip install --no-cache-dir \
    torch==2.5.1+cpu \
    torchvision==0.20.1+cpu \
    torchaudio==2.5.1+cpu \
    --index-url https://download.pytorch.org/whl/cpu

# Научные пакеты
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgeos-dev libproj-dev \
    texlive-latex-recommended \
    texlive-fonts-recommended \
    texlive-xetex \
    texlive-luatex \
    cm-super \
    && pip install --no-cache-dir \
    numpy==1.26.4 scipy pandas scikit-learn matplotlib \
    transformers datasets==3.5.1 \
    pydotplus openpyxl folium mglearn basemap \
    tensorflow-cpu==2.15.0 tensorflow-text==2.15.0 \
    opencv-python-headless segmentation-models-pytorch efficientnet_pytorch \
    pillow imageio jiwer SpeechRecognition soundfile librosa openai-whisper \
    nltk rouge-score umap-learn seaborn \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# pydensecrf (Eigen headers + Cython<3)
# ============================================
RUN pip install --no-cache-dir "cython<3" "setuptools" wheel && \
    pip install --no-cache-dir git+https://github.com/lucasb-eyer/pydensecrf.git#egg=pydensecrf
# ============================================
# NLTK data (общий путь для всех пользователей)
# ============================================
RUN python -m nltk.downloader -d /usr/share/nltk_data \
    brown \
    punkt \
    punkt_tab \
    wordnet \
    averaged_perceptron_tagger \
    averaged_perceptron_tagger_eng \
    omw-1.4 \
    stopwords

# ============================================
# Предзагрузка моделей/датасетов в общий HF/torch cache
# ============================================
ENV HF_SKIP_CHECK_TORCH_LOAD_IS_SAFE=1
RUN mkdir -p /hf-cache/hub /hf-cache/datasets /hf-cache/transformers /hf-cache/xdg-cache /shared/torch-cache /opt/istp-data && \
    python - <<'PY'
from datasets import load_dataset
from transformers import AutoModel, AutoTokenizer, Wav2Vec2ForCTC, Wav2Vec2Processor
import whisper
from torchvision.models import resnet34
from torchvision.models.detection import maskrcnn_resnet50_fpn

AutoTokenizer.from_pretrained("bert-base-uncased")
AutoModel.from_pretrained("bert-base-uncased", use_safetensors=True)
Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-large-960h-lv60-self")
Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-large-960h-lv60-self", use_safetensors=True)
whisper.load_model("base")
load_dataset("glue", "stsb")
resnet34(weights="IMAGENET1K_V1")
maskrcnn_resnet50_fpn(weights="COCO_V1")
PY
RUN chmod -R 0777 /hf-cache /shared/torch-cache

# ============================================
# Данные для setup.sh (распаковываются в shared-data volume)
# data.zip нужно предварительно скачать из https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/releases/download/v1.1/data.zip
# Canada.xlsx качается из https://s3-api.us-geo.objectstorage.softlayer.net/cf-courses-data/CognitiveClass/DV0101EN/labs/Data_Files/Canada.xlsx
# ============================================
COPY ./data.zip /opt/istp-data/data.zip
COPY data/Canada.xlsx /opt/istp-data/Canada.xlsx

WORKDIR /app

# Копирование конфигураций
COPY jupyterhub_config.py /app/jupyterhub_config.py
COPY jupyter_ai_config.json /etc/jupyter/jupyter_ai_config.json
COPY persona_mentor.py /app/persona_mentor.py
COPY startup/ /app/startup/
COPY startup-hooks/ /app/startup-hooks/
COPY ipython_kernel_config.py /usr/local/etc/ipython/ipython_kernel_config.py

# Указываем IPython использовать системный профиль
ENV IPYTHONDIR=/usr/local/etc/ipython

# Добавление shared packages в PYTHONPATH
RUN echo "/usr/local/lib/python3.10/shared-packages" > /usr/local/lib/python3.10/site-packages/shared-packages.pth

# Создание групп и директорий с правильными правами
RUN mkdir -p /usr/local/lib/python3.10/shared-packages && \
    groupadd shared-packages 2>/dev/null || true && \
    chown root:shared-packages /usr/local/lib/python3.10/shared-packages && \
    chmod 775 /usr/local/lib/python3.10/shared-packages && \
    mkdir -p /shared/pip-cache /hf-cache && \
    chown root:shared-packages /shared/pip-cache && \
    chmod 775 /shared/pip-cache && \
    chown root:shared-packages /hf-cache && \
    chmod 775 /hf-cache

# Копирование скрипта для генерации SSH-ключей
RUN chmod +x /app/startup-hooks/generate_ssh_keys.py

EXPOSE 8000

CMD ["jupyterhub", "--config", "/app/jupyterhub_config.py"]
