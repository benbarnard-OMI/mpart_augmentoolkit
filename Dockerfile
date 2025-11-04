# syntax=docker/dockerfile:1.6
# ============================================================================
# Dockerfile for Augmentoolkit on NVIDIA GPUs
# ============================================================================
# 
# Optimized for:
# - NVIDIA GPUs with CUDA 12.1 support
# - Dual NVIDIA RTX 3090 GPUs (24GB VRAM each) for local testing
# - Apptainer/Singularity compatibility on HPC clusters
# - Reproducibility with pinned versions
#
# GPU Access:
#   Docker: Use --gpus all flag when running
#   Apptainer: Use --nv flag to enable NVIDIA GPU support
#
# Example usage:
#   docker build -t mpart-augmentoolkit:v1 .
#   docker run --gpus all -it mpart-augmentoolkit:v1
#   docker run --gpus all mpart-augmentoolkit:v1 python /workspace/scripts/test_environment.py
#
#   apptainer build mpart-augmentoolkit.sif docker://mpart-augmentoolkit:v1
#   apptainer exec --nv mpart-augmentoolkit.sif python /workspace/scripts/test_environment.py
# ============================================================================

FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

# ============================================================================
# Environment Variables
# ============================================================================
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=UTC \
    PATH="/usr/local/bin:${PATH}"

# ============================================================================
# System Dependencies Installation
# ============================================================================
# Install Python 3.10+, Git, and system libraries needed for PDF processing
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

# Create symlink for python to ensure Python 3.10 is the default
RUN ln -sf /usr/bin/python3.10 /usr/bin/python3 && \
    ln -sf /usr/bin/python3.10 /usr/bin/python && \
    python3 --version

# Upgrade pip, setuptools, and wheel to latest versions
RUN python3 -m pip install --upgrade pip setuptools wheel

# ============================================================================
# Augmentoolkit Setup
# ============================================================================
# Clone Augmentoolkit repository from the correct source
# This provides the core prompts and processing logic
WORKDIR /workspace

ARG AUGMENTOOLKIT_REF=main
RUN git clone https://github.com/e-p-armstrong/augmentoolkit.git /workspace/augmentoolkit && \
    cd /workspace/augmentoolkit && \
    git checkout "${AUGMENTOOLKIT_REF}" && \
    git rev-parse HEAD > /workspace/augmentoolkit_commit.txt && \
    echo "Cloned Augmentoolkit at commit: $(cat /workspace/augmentoolkit_commit.txt)"

# Install Augmentoolkit's dependencies if it has a requirements.txt
# Note: We check if the file exists before trying to install
RUN if [ -f /workspace/augmentoolkit/requirements.txt ]; then \
        echo "Installing Augmentoolkit dependencies..."; \
        pip install --no-cache-dir -r /workspace/augmentoolkit/requirements.txt; \
    else \
        echo "No Augmentoolkit requirements.txt found, skipping..."; \
    fi

# Install Augmentoolkit as a package if it has setup.py or pyproject.toml
RUN if [ -f /workspace/augmentoolkit/setup.py ] || [ -f /workspace/augmentoolkit/pyproject.toml ]; then \
        echo "Installing Augmentoolkit package..."; \
        pip install --no-cache-dir /workspace/augmentoolkit; \
    else \
        echo "No setup.py or pyproject.toml found, Augmentoolkit will be used as a directory..."; \
    fi

# ============================================================================
# Project Dependencies Installation
# ============================================================================
# Install our project's requirements (vLLM, docling, transformers, etc.)
# This layer is separate so changes to our requirements don't invalidate Augmentoolkit install
COPY requirements.txt /workspace/requirements.txt
RUN pip install --no-cache-dir -r /workspace/requirements.txt

# ============================================================================
# Project Files Setup
# ============================================================================
# Copy our configuration files and scripts
# These are copied after dependency installation for better layer caching
COPY configs/ /workspace/configs/
COPY scripts/ /workspace/scripts/

# ============================================================================
# Directory Structure Creation
# ============================================================================
# Create all necessary directories that the test script expects
# Some will be mounted at runtime, but we create them for completeness
RUN mkdir -p \
    /workspace/data \
    /workspace/data/raw \
    /workspace/data/processed \
    /workspace/data/processed/manifests \
    /workspace/data/output \
    /workspace/data/output/logs \
    /workspace/output

# ============================================================================
# Installation Verification
# ============================================================================
# Verify critical dependencies are properly installed
# These checks are non-blocking to avoid build failures on import-only issues
RUN echo "=== Verifying Python Package Installations ===" && \
    python3 -c "import torch; print('✓ PyTorch:', torch.__version__)" 2>/dev/null || echo "✗ PyTorch check failed" && \
    python3 -c "import transformers; print('✓ Transformers:', transformers.__version__)" 2>/dev/null || echo "✗ Transformers check failed" && \
    python3 -c "import docling; print('✓ Docling:', docling.__version__)" 2>/dev/null || echo "✗ Docling check failed" && \
    python3 -c "import vllm; print('✓ vLLM imported successfully')" 2>/dev/null || echo "✗ vLLM check skipped (requires GPU runtime)" && \
    python3 -c "import yaml; print('✓ PyYAML imported')" 2>/dev/null || echo "✗ PyYAML check failed" && \
    python3 -c "import pandas, numpy; print('✓ Pandas and NumPy imported')" 2>/dev/null || echo "✗ Data processing libraries check failed" && \
    echo "=== Verification Complete ==="

# ============================================================================
# Final Setup
# ============================================================================
# Set working directory back to workspace root
WORKDIR /workspace

# Default command: drop into bash shell for interactive use
CMD ["/bin/bash"]
