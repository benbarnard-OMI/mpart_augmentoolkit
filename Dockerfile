# Augmentoolkit Docker Container for UIUC Campus Cluster
# Based on NVIDIA CUDA runtime for GPU acceleration
FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8 \
    PATH="/opt/conda/bin:${PATH}" \
    AUGMENTOOLKIT_VERSION=3.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    build-essential \
    software-properties-common \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    tesseract-ocr \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Create working directory
WORKDIR /augmentoolkit

# Clone augmentoolkit repository
RUN git clone https://github.com/e-p-armstrong/augmentoolkit.git . && \
    git checkout main

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# Install Redis/Valkey (required by augmentoolkit)
RUN apt-get update && apt-get install -y redis-server && \
    rm -rf /var/lib/apt/lists/*

# Create directories for inputs, outputs, and configs
RUN mkdir -p /data/inputs /data/outputs /data/configs /data/models /data/cache

# Copy container-specific configuration and scripts
COPY config.yaml /augmentoolkit/container_config.yaml
COPY entrypoint.sh /augmentoolkit/entrypoint.sh
RUN chmod +x /augmentoolkit/entrypoint.sh

# Expose ports (if needed for API/interface)
EXPOSE 7860 8003

# Set entrypoint
ENTRYPOINT ["/augmentoolkit/entrypoint.sh"]

# Default command (can be overridden)
CMD ["--config", "/augmentoolkit/container_config.yaml"]
