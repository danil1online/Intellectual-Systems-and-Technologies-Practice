#FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04
FROM ghcr.io/ggml-org/llama.cpp:server-cuda12

# Установка зависимостей
#RUN apt-get update && apt-get install -y --no-install-recommends \
#    build-essential \
#    git \
#    cmake \
#    ccache \
#    wget \
#    ca-certificates \
#    libcurl4-openssl-dev \
#    && rm -rf /var/lib/apt/lists/*

# Клонирование и компиляция llama.cpp
#RUN git clone --depth 1 https://github.com/ggml-org/llama.cpp.git /opt/llama.cpp \
#    && cd /opt/llama.cpp \
#    && cmake -B build \
#        -DBUILD_SHARED_LIBS=OFF \
#        -DGGML_CUDA_DYN=ON \
#        -DGGML_CUDA=ON \
#        -DGGML_CUDA_F16=ON \
#        -DCMAKE_CUDA_ARCHITECTURES=86 \
#    && cmake --build build --config Release -j$(nproc)

COPY start-server.sh /usr/local/bin/start-server.sh
RUN chmod +x /usr/local/bin/start-server.sh

COPY initialize.sh /app/initialize.sh
RUN chmod +x /app/initialize.sh

WORKDIR /app

ENTRYPOINT ["/usr/local/bin/start-server.sh"]
