FROM python:3.10-slim

# Установка Node.js для configurable-http-proxy
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    openssh-client \
    procps \
    build-essential \
    && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Установка configurable-http-proxy
RUN npm install -g configurable-http-proxy

# Установка Python пакетов
RUN pip install --no-cache-dir \
    jupyterhub==4.1.6 \
    jupyterlab==4.3.4 \
    notebook==7.3.2 \
    oauthenticator==17.4.0 \
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
    torch torchvision torchaudio \
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
    numpy scipy pandas scikit-learn matplotlib \
    transformers datasets==3.5.1 \
    pydotplus openpyxl folium mglearn basemap \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Копирование конфигураций
COPY jupyterhub_config.py /app/jupyterhub_config.py
COPY jupyter_ai_config.json /etc/jupyter/jupyter_ai_config.json
COPY persona_mentor.py /app/persona_mentor.py
COPY startup/ /app/startup/
COPY startup-hooks/ /app/startup-hooks/

# Создание директорий
RUN mkdir -p /app/logs /home/jovyan/shared/data /home/jovyan/shared/student-work /shared/data /shared/data/cache_huggingface /shared/pip-cache

# Добавление shared packages в PYTHONPATH
RUN echo "/usr/local/lib/python3.10/shared-packages" > /usr/local/lib/python3.10/site-packages/shared-packages.pth

# Копирование скрипта для генерации SSH-ключей
RUN chmod +x /app/startup-hooks/generate_ssh_keys.py

EXPOSE 8000

CMD ["jupyterhub", "--config", "/app/jupyterhub_config.py"]
