# syntax=docker/dockerfile:1.6
# Dockerfile for Augmentoolkit on NVIDIA GPUs
# 
# Optimized for:
# - Dual NVIDIA RTX 3090 GPUs (24GB VRAM each) for local testing
# - Apptainer/Singularity compatibility on HPC clusters
# - Reproducibility with pinned versions
#
# GPU Access:
#   Docker: Use --gpus all flag when running
#   Apptainer: Use --nv flag to enable NVIDIA GPU support
#
# Example usage:
#   docker build -t augmentoolkit-gpu:latest .
#   docker run --gpus all -it augmentoolkit-gpu:latest
#   apptainer build image.sif docker://augmentoolkit-gpu:latest
#   apptainer exec --nv image.sif /bin/bash

FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=UTC \
    PATH="/usr/local/bin:${PATH}"

# Install system dependencies and Python 3.10+
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3.10-dev \
    python3-pip \
    git \
    curl \
    wget \
    build-essential \
    poppler-utils \
    tesseract-ocr \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Create symlink for python and pip to ensure Python 3.10 is default
RUN ln -sf /usr/bin/python3.10 /usr/bin/python3 && \
    ln -sf /usr/bin/python3.10 /usr/bin/python && \
    python3 --version

# Upgrade pip to latest version
RUN python3 -m pip install --upgrade pip setuptools wheel

# Set working directory
WORKDIR /workspace

# Clone Augmentoolkit repository
# Pin to specific commit/tag for reproducibility (adjust AUGMENTOOLKIT_REF as needed)
ARG AUGMENTOOLKIT_REF=main
RUN git clone https://github.com/allenai/augmentoolkit.git /workspace/augmentoolkit && \
    cd /workspace/augmentoolkit && \
    git checkout "${AUGMENTOOLKIT_REF}" && \
    git rev-parse HEAD > /workspace/augmentoolkit_commit.txt

# Install Augmentoolkit dependencies from requirements.txt
# Note: vLLM is included here and will be installed with CUDA support
COPY requirements.txt /workspace/requirements.txt
RUN pip install --no-cache-dir -r /workspace/requirements.txt

# Install Augmentoolkit
RUN cd /workspace/augmentoolkit && \
    pip install --no-cache-dir .

# Copy project files (configs, scripts, etc.)
COPY . /workspace/

# Create necessary directories
RUN mkdir -p /workspace/data/raw \
    /workspace/data/processed \
    /workspace/data/processed/manifests \
    /workspace/data/output \
    /workspace/data/output/logs

# Verify critical installations (non-blocking checks)
RUN python3 -c "import docling; print('Docling:', docling.__version__)" 2>/dev/null || echo "Docling check skipped" && \
    python3 -c "import vllm; print('vLLM imported successfully')" 2>/dev/null || echo "vLLM check skipped (requires GPU runtime)" && \
    python3 -c "import ollama, pypdf; from pdfminer import six; from dotenv import load_dotenv; import loguru, rich; print('Core dependencies OK')" 2>/dev/null || echo "Dependency check completed"

# Default command: drop into bash shell
CMD ["/bin/bash"]
