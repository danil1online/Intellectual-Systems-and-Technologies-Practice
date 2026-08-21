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
    graphviz \
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
ENV KERAS_HOME=/hf-cache/keras
ENV SKLEARN_DATA_HOME=/hf-cache/sklearn-data
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
    torch==2.6.0+cpu \
    torchvision==0.21.0+cpu \
    torchaudio==2.6.0+cpu \
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
RUN mkdir -p \
    /hf-cache/hub \
    /hf-cache/datasets \
    /hf-cache/transformers \
    /hf-cache/xdg-cache \
    /hf-cache/keras \
    /hf-cache/sklearn-data \
    /shared/torch-cache \
    /shared/data \
    /opt/istp-data
RUN --mount=type=secret,id=HF_TOKEN \
    HF_TOKEN=$(cat /run/secrets/HF_TOKEN) \
    python - <<'PY'
from datasets import load_dataset
from transformers import (
    AutoModel,
    AutoModelForCausalLM,
    AutoModelForSequenceClassification,
    AutoTokenizer,
    Wav2Vec2ForCTC,
    Wav2Vec2Processor,
)
import whisper
from torchvision.models import resnet34
from torchvision.models.detection import maskrcnn_resnet50_fpn
from sklearn.datasets import fetch_20newsgroups
from tensorflow.keras.datasets import mnist as tf_mnist
from tensorflow.keras.applications.inception_v3 import InceptionV3
import segmentation_models_pytorch as smp

AutoTokenizer.from_pretrained("bert-base-uncased")
AutoModel.from_pretrained("bert-base-uncased")
Wav2Vec2Processor.from_pretrained("facebook/wav2vec2-large-960h-lv60-self")
Wav2Vec2ForCTC.from_pretrained("facebook/wav2vec2-large-960h-lv60-self")
whisper.load_model("base")
load_dataset("nyu-mll/glue", "stsb")
load_dataset("google-research-datasets/poem_sentiment")
AutoTokenizer.from_pretrained("nickwong64/bert-base-uncased-poems-sentiment")
AutoModelForSequenceClassification.from_pretrained("nickwong64/bert-base-uncased-poems-sentiment")
AutoTokenizer.from_pretrained("EleutherAI/gpt-neo-1.3B")
AutoModelForCausalLM.from_pretrained("EleutherAI/gpt-neo-1.3B")
fetch_20newsgroups(subset="train", shuffle=False, random_state=42)
fetch_20newsgroups(subset="test", shuffle=False, random_state=42)
tf_mnist.load_data()
InceptionV3(weights="imagenet")
smp.Unet(
    encoder_name="resnet34",
    encoder_weights="imagenet",
    in_channels=3,
    classes=1
)
resnet34(weights="IMAGENET1K_V1")
maskrcnn_resnet50_fpn(weights="COCO_V1")
PY
RUN printf '2' > /hf-cache/.istp-hf-version
RUN printf '2' > /shared/torch-cache/.istp-torch-version
RUN chmod -R 0777 /hf-cache /shared/torch-cache

# ============================================
# Данные для студентов: /shared/data -> ~/data
# data.zip нужно предварительно скачать из https://github.com/danil1online/Intellectual-Systems-and-Technologies-Practice/releases/download/v1.1/data.zip
# Canada.xlsx качается из https://s3-api.us-geo.objectstorage.softlayer.net/cf-courses-data/CognitiveClass/DV0101EN/labs/Data_Files/Canada.xlsx
# PennFudanPed кладётся локально в jupyterhub/data/PennFudanPed
# ============================================
COPY ./data.zip /opt/istp-data/data.zip
COPY data/ /shared/data/
RUN mkdir -p /shared/data && \
    python3 -m zipfile -e /opt/istp-data/data.zip /shared/data/ && \
    rm -f /opt/istp-data/data.zip
RUN python - <<'PY'
import os
import subprocess
import tarfile
import urllib.request

from torchvision import datasets as tv_datasets
#tv_datasets.MNIST.mirrors = ["https://amazonaws.com"]

root = "/shared/data"
os.makedirs(root, exist_ok=True)

tv_datasets.MNIST(root=root, train=True, download=True)
tv_datasets.MNIST(root=root, train=False, download=True)
tv_datasets.FashionMNIST(root=root, train=True, download=True)
tv_datasets.FashionMNIST(root=root, train=False, download=True)

asr_root = os.path.join(root, "asr")
audio_root = os.path.join(asr_root, "audio")
transcripts_root = os.path.join(asr_root, "transcripts")
os.makedirs(audio_root, exist_ok=True)
os.makedirs(transcripts_root, exist_ok=True)

url = "http://www.openslr.org/resources/12/dev-clean.tar.gz"
archive = "/tmp/dev-clean.tar.gz"
if not os.path.exists(archive):
    urllib.request.urlretrieve(url, archive)

wanted_ids = []
with tarfile.open(archive, "r:gz") as tar:
    for member in tar.getmembers():
        if member.name.endswith(".flac") and len(wanted_ids) < 10:
            flac_name = os.path.basename(member.name)
            utt_id = os.path.splitext(flac_name)[0]
            wanted_ids.append(utt_id)
            flac_path = os.path.join(audio_root, f"{utt_id}.flac")
            wav_path = os.path.join(audio_root, f"{utt_id}.wav")
            with open(flac_path, "wb") as out:
                out.write(tar.extractfile(member).read())
            subprocess.run(
                ["ffmpeg", "-y", "-i", flac_path, wav_path],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

with tarfile.open(archive, "r:gz") as tar:
    for member in tar.getmembers():
        if not member.name.endswith(".trans.txt"):
            continue
        content = tar.extractfile(member).read().decode("utf-8")
        for line in content.splitlines():
            if not line:
                continue
            utt_id, text = line.split(" ", 1)
            if utt_id in wanted_ids:
                with open(os.path.join(transcripts_root, f"{utt_id}.txt"), "w", encoding="utf-8") as out:
                    out.write(text)
PY
RUN rm -f /tmp/dev-clean.tar.gz
RUN printf '2' > /shared/data/.istp-data-version
RUN chmod -R a+rX /shared/data

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
    chmod 0777 /hf-cache

# Копирование скрипта для генерации SSH-ключей
RUN chmod +x /app/startup-hooks/generate_ssh_keys.py

EXPOSE 8000

CMD ["jupyterhub", "--config", "/app/jupyterhub_config.py"]
