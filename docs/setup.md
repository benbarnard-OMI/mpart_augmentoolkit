# Local Development Setup Guide

> **Last Updated**: 2025-11-04

This guide will walk you through setting up the MPART Augmentoolkit project on your local machine for development and testing. By the end of this guide, you'll have a working environment to process sample Medicaid PDFs and generate QA pairs locally.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Building the Docker Image](#building-the-docker-image)
- [Testing GPU Access](#testing-gpu-access)
- [Setting Up vLLM Server](#setting-up-vllm-server)
- [Processing Sample PDFs](#processing-sample-pdfs)
- [Running the Test Environment Script](#running-the-test-environment-script)
- [Running Augmentoolkit Locally](#running-augmentoolkit-locally)
- [Troubleshooting Common Issues](#troubleshooting-common-issues)
- [Next Steps](#next-steps)

## Prerequisites

Before starting, ensure you have:

### Hardware Requirements
- **GPU**: NVIDIA GPU with at least 24GB VRAM (tested with dual RTX 3090)
  - For Llama 3.1 70B: Minimum 40GB VRAM recommended (or use quantization)
  - For local testing with smaller models: 16GB+ VRAM acceptable
- **RAM**: 32GB+ system RAM recommended
- **Storage**: 100GB+ free disk space for:
  - Docker images (~15GB)
  - Model weights (~150GB for Llama 3.1 70B)
  - Data and outputs (~50GB)

### Software Requirements
- **Operating System**: Linux (Ubuntu 22.04 recommended)
- **CUDA**: Version 12.1 or higher
- **Docker**: Version 20.10 or higher
- **NVIDIA Container Toolkit**: For Docker GPU support
- **Git**: For version control

### Verify CUDA Installation
```bash
nvidia-smi
```

Expected output should show your GPU(s) and CUDA version:
```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 525.xx.xx    Driver Version: 525.xx.xx    CUDA Version: 12.1   |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  NVIDIA GeForce ...  Off  | 00000000:01:00.0 Off |                  N/A |
| 30%   45C    P8    20W / 350W |      0MiB / 24576MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
```

### Verify Docker and NVIDIA Container Toolkit
```bash
# Check Docker version
docker --version

# Test Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

If this fails, install NVIDIA Container Toolkit:
```bash
# Add NVIDIA repository
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

# Install
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Restart Docker
sudo systemctl restart docker
```

## Initial Setup

### 1. Clone the Repository
```bash
git clone https://github.com/your-org/medicaid-qa-generation.git
cd medicaid-qa-generation
```

### 2. Create Data Directories
```bash
mkdir -p data/raw
mkdir -p data/processed/sample
mkdir -p data/processed/manifests
mkdir -p data/output
mkdir -p logs
```

### 3. Add Sample PDFs
Place 5-10 sample Medicaid policy PDFs in `data/raw/` for initial testing:
```bash
# Example structure
data/raw/
├── policy_001.pdf
├── policy_002.pdf
├── policy_003.pdf
├── policy_004.pdf
└── policy_005.pdf
```

⚠️ **Important**: Start with a small number of PDFs (5-10) to validate your setup before processing the full dataset.

## Building the Docker Image

### 1. Review the Dockerfile
Before building, review the `Dockerfile` to understand what's being installed:
- Base: NVIDIA CUDA 12.1 on Ubuntu 22.04
- Python 3.10 with all dependencies from `requirements.txt`
- Augmentoolkit cloned from GitHub
- PDF processing tools (Docling, Tesseract, Poppler)

### 2. Build the Image
```bash
docker build -t mpart-augmentoolkit:v1 .
```

This will take 10-15 minutes depending on your internet connection. You'll see output like:
```
[+] Building 847.2s (15/15) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 5.23kB
 => [internal] load .dockerignore
 => => transferring context: 2B
 => [internal] load metadata for docker.io/nvidia/cuda:12.1.0-runtime-ubuntu22.04
...
 => => naming to docker.io/library/mpart-augmentoolkit:v1
```

### 3. Verify the Build
```bash
docker images | grep mpart-augmentoolkit
```

Expected output:
```
mpart-augmentoolkit   v1      abc123def456   2 minutes ago   8.5GB
```

💡 **Tip**: Tag different versions as you make changes (v1, v2, etc.) to track iterations.

### 4. Optional: Build with Custom Augmentoolkit Version
If you need a specific Augmentoolkit commit:
```bash
docker build \
  --build-arg AUGMENTOOLKIT_REF=commit-hash-or-branch \
  -t mpart-augmentoolkit:v1-custom .
```

## Testing GPU Access

### 1. Basic GPU Test
Verify GPUs are accessible inside the container:
```bash
docker run --gpus all mpart-augmentoolkit:v1 nvidia-smi
```

You should see the same output as running `nvidia-smi` on the host.

### 2. PyTorch GPU Test
Verify PyTorch can access the GPU:
```bash
docker run --gpus all mpart-augmentoolkit:v1 python3 -c "import torch; print(f'CUDA Available: {torch.cuda.is_available()}'); print(f'GPU Count: {torch.cuda.device_count()}'); print(f'GPU Name: {torch.cuda.get_device_name(0)}')"
```

Expected output:
```
CUDA Available: True
GPU Count: 2
GPU Name: NVIDIA GeForce RTX 3090
```

### 3. Multi-GPU Test (if applicable)
If you have multiple GPUs:
```bash
docker run --gpus all mpart-augmentoolkit:v1 python3 -c "import torch; [print(f'GPU {i}: {torch.cuda.get_device_name(i)}') for i in range(torch.cuda.device_count())]"
```

## Setting Up vLLM Server

To run Augmentoolkit, you need an inference endpoint. We recommend vLLM for efficient serving of Llama 3.1 70B.

### Option 1: Local vLLM Server (Requires 40GB+ VRAM)

#### Install vLLM in a separate terminal:
```bash
pip install vllm
```

#### Start vLLM server with Llama 3.1 70B:
```bash
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-70B-Instruct \
  --tensor-parallel-size 2 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 8192 \
  --port 8000
```

⚠️ **Note**: This requires ~150GB of disk space for model weights and 40GB+ GPU memory. For dual RTX 3090 (24GB each), tensor parallelism splits the model across both GPUs.

#### Verify server is running:
```bash
curl http://localhost:8000/v1/models
```

Expected response:
```json
{
  "object": "list",
  "data": [
    {
      "id": "meta-llama/Llama-3.1-70B-Instruct",
      "object": "model",
      "created": 1234567890,
      "owned_by": "vllm"
    }
  ]
}
```

### Option 2: Remote API Endpoint

If you have access to a hosted vLLM endpoint or OpenAI-compatible API:

```bash
export LLAMA_API_KEY="your-api-key-here"
export VLLM_BASE_URL="https://your-endpoint.com/v1"
export LLAMA_MODEL="meta-llama/Llama-3.1-70B-Instruct"
```

### Option 3: Smaller Model for Testing (Recommended for Initial Setup)

For quick testing without 70B model requirements:
```bash
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-8B-Instruct \
  --gpu-memory-utilization 0.7 \
  --port 8000
```

This only requires ~16GB GPU memory and is perfect for validating your pipeline before scaling up.

## Processing Sample PDFs

### 1. Convert PDFs to Markdown
Augmentoolkit works best with markdown input. Use Docling to convert PDFs:

```bash
docker run --gpus all \
  -v $(pwd)/data:/workspace/data \
  mpart-augmentoolkit:v1 \
  python /workspace/scripts/preprocessing/convert_pdfs.py \
  --input-dir /workspace/data/raw \
  --output-dir /workspace/data/processed/sample \
  --limit 5
```

#### What this does:
- Mounts your local `data/` directory to `/workspace/data` in the container
- Runs the conversion script on up to 5 PDFs
- Outputs markdown files to `data/processed/sample/`

#### Expected output:
```
Processing PDFs from /workspace/data/raw...
Converting policy_001.pdf... ✓ Done (3.2s)
Converting policy_002.pdf... ✓ Done (2.8s)
Converting policy_003.pdf... ✓ Done (4.1s)
Converting policy_004.pdf... ✓ Done (3.5s)
Converting policy_005.pdf... ✓ Done (2.9s)

Processed 5 PDFs in 16.5 seconds
Output saved to /workspace/data/processed/sample/
```

### 2. Verify Markdown Output
```bash
ls -lh data/processed/sample/
cat data/processed/sample/policy_001.md | head -20
```

Good markdown should have:
- Clear section headers
- Properly formatted paragraphs
- Tables (if present in PDF) converted to markdown format
- Minimal OCR errors

💡 **Tip**: If markdown quality is poor, consider using different Docling settings or manually correcting a few samples for testing.

## Running the Test Environment Script

Before running the full pipeline, validate your environment:

```bash
docker run --gpus all \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/configs:/workspace/configs \
  -v $(pwd)/logs:/workspace/logs \
  mpart-augmentoolkit:v1 \
  python /workspace/scripts/test_environment.py
```

#### What this checks:
- ✓ Python version and packages
- ✓ GPU availability and CUDA version
- ✓ Directory structure
- ✓ Configuration file validity
- ✓ Augmentoolkit installation

#### Expected output:
```
========================================
Environment Test Report
========================================
✓ Python 3.10.12
✓ PyTorch 2.1.0+cu121
✓ CUDA Available: True
✓ GPU Count: 2
✓ GPU 0: NVIDIA GeForce RTX 3090 (24GB)
✓ GPU 1: NVIDIA GeForce RTX 3090 (24GB)
✓ Transformers 4.36.2
✓ Docling 0.0.14
✓ vLLM 0.5.4
✓ Directory structure valid
✓ medicaid_config.yaml found and valid
✓ Augmentoolkit installed

All checks passed! Environment is ready.
========================================
```

If any checks fail, see the [Troubleshooting](#troubleshooting-common-issues) section below.

## Running Augmentoolkit Locally

Now you're ready to generate QA pairs from your sample PDFs!

### 1. Set Environment Variables
```bash
export LLAMA_API_KEY="your-key-here"  # Or leave blank if using local vLLM
export VLLM_BASE_URL="http://localhost:8000/v1"  # Or your remote endpoint
export LLAMA_MODEL="meta-llama/Llama-3.1-70B-Instruct"
```

### 2. Run Augmentoolkit on Sample Data
```bash
docker run --gpus all \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/configs:/workspace/configs \
  -v $(pwd)/logs:/workspace/logs \
  -e LLAMA_API_KEY="${LLAMA_API_KEY}" \
  -e VLLM_BASE_URL="${VLLM_BASE_URL}" \
  -e LLAMA_MODEL="${LLAMA_MODEL}" \
  --network host \
  mpart-augmentoolkit:v1 \
  augmentoolkit --config /workspace/configs/medicaid_config.yaml
```

#### Important flags explained:
- `--gpus all`: Enables GPU access
- `-v`: Mounts directories for data, configs, and logs
- `-e`: Passes environment variables
- `--network host`: Allows container to access host's localhost (for vLLM)

### 3. Monitor Progress
Open another terminal and watch the logs:
```bash
tail -f logs/latest.log
```

You should see output like:
```
[INFO] Starting Augmentoolkit pipeline...
[INFO] Loading configuration from /workspace/configs/medicaid_config.yaml
[INFO] Processing 5 markdown files from /workspace/data/processed/sample
[INFO] Chunk 1/25: Generating questions...
[INFO] Generated 5 QA pairs for chunk 1
[INFO] Chunk 2/25: Generating questions...
...
```

### 4. Check Output
After completion (typically 5-15 minutes for 5 PDFs):
```bash
ls -lh data/output/
cat data/output/dataset.jsonl | head -5
```

Expected output structure:
```json
{"id": "qa_001", "question": "What are the eligibility requirements for Medicaid?", "answer": "According to the policy document...", "source": "policy_001.pdf", "metadata": {...}}
{"id": "qa_002", "question": "How do beneficiaries appeal coverage denials?", "answer": "The appeals process involves...", "source": "policy_001.pdf", "metadata": {...}}
```

## Troubleshooting Common Issues

### Issue: Docker build fails with "No space left on device"
**Solution**: Clean up Docker:
```bash
docker system prune -a
```

### Issue: GPU not accessible in container
**Check**:
```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

**Solution**: Reinstall NVIDIA Container Toolkit (see [Prerequisites](#prerequisites))

### Issue: vLLM server won't start - Out of Memory
**Solution**: Use smaller model or reduce parameters:
```bash
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-8B-Instruct \
  --gpu-memory-utilization 0.6 \
  --max-model-len 4096
```

### Issue: Augmentoolkit can't connect to vLLM
**Check**: Verify vLLM server is running:
```bash
curl http://localhost:8000/v1/models
```

**Solution**: Make sure you're using `--network host` in docker run command

### Issue: Markdown conversion produces poor quality output
**Solution**: 
1. Check PDF quality - scanned PDFs need OCR
2. Try manual conversion for critical documents
3. Adjust Docling parameters in `convert_pdfs.py`

### Issue: "ImportError: cannot import name 'X' from 'augmentoolkit'"
**Solution**: Rebuild Docker image to get latest Augmentoolkit:
```bash
docker build --no-cache -t mpart-augmentoolkit:v1 .
```

For more issues, see [docs/troubleshooting.md](troubleshooting.md)

## Next Steps

Congratulations! You now have a working local setup. Here's what to do next:

### 1. Review Generated QA Pairs
Manually inspect the quality of generated QA pairs:
```bash
# View in JSON format
cat data/output/dataset.jsonl | jq '.'

# Count total pairs
wc -l data/output/dataset.jsonl
```

Evaluate:
- Are questions relevant and specific?
- Are answers accurate and grounded in source text?
- Are sources properly cited?

### 2. Adjust Configuration
Edit `configs/medicaid_config.yaml` to tune parameters:
- `system.number_of_factual_sft_generations_to_do`: Increase/decrease QA pairs per chunk
- `system.chunk_size`: Adjust chunk size for better context
- `system.concurrency_limit`: Increase for faster processing (if hardware allows)

### 3. Process More Sample PDFs
Scale up to 20-50 PDFs locally to gather better benchmarks:
```bash
docker run --gpus all \
  -v $(pwd)/data:/workspace/data \
  mpart-augmentoolkit:v1 \
  python /workspace/scripts/preprocessing/convert_pdfs.py \
  --input-dir /workspace/data/raw \
  --output-dir /workspace/data/processed \
  --limit 50
```

### 4. Record Benchmarks
Document your local performance in [docs/benchmarks.md](benchmarks.md):
- Average time per PDF
- GPU utilization percentage
- QA pairs generated per PDF
- Memory usage

### 5. Prepare for Cluster Deployment
Once satisfied with local results, move to cluster deployment:
- Read [docs/campus_cluster_deployment.md](campus_cluster_deployment.md)
- Push Docker image to Docker Hub or container registry
- Prepare data transfer to cluster storage

### 6. Review Workflow
Understand the complete pipeline by reading [docs/workflow.md](workflow.md)

---

**Questions?** Check [docs/troubleshooting.md](troubleshooting.md) or reach out on Slack (#medicaid-qa).

**Ready for production?** See [docs/campus_cluster_deployment.md](campus_cluster_deployment.md) for cluster deployment instructions.
