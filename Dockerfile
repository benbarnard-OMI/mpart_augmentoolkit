# syntax=docker/dockerfile:1.6

FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv git curl wget build-essential \
    poppler-utils tesseract-ocr && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./requirements.txt
RUN python3 -m pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Clone Augmentoolkit (pin to commit to ensure reproducibility)
ARG AUGMENTOOLKIT_REF=main
RUN git clone https://github.com/allenai/augmentoolkit.git && \
    cd augmentoolkit && \
    git checkout "$AUGMENTOOLKIT_REF" && \
    pip install --no-cache-dir .

# Copy project
COPY . .

# Create non-root user for security
RUN useradd -m pipeline && chown -R pipeline:pipeline /app
USER pipeline

ENV PATH="/home/pipeline/.local/bin:${PATH}"

CMD ["augmentoolkit", "--help"]
