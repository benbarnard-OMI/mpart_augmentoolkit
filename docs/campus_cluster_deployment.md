# Campus Cluster Deployment Guide

> **Last Updated**: 2025-11-04

This guide covers the complete workflow for deploying the MPART Augmentoolkit pipeline on the UIUC Campus Cluster, from container preparation through production job submission and result retrieval.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Step 1: Campus Cluster Access](#step-1-campus-cluster-access)
- [Step 2: Container Preparation](#step-2-container-preparation)
- [Step 3: Data Transfer](#step-3-data-transfer)
- [Step 4: Environment Setup on Cluster](#step-4-environment-setup-on-cluster)
- [Step 5: Smoke Testing](#step-5-smoke-testing)
- [Step 6: Batch Processing](#step-6-batch-processing)
- [Step 7: Production Run](#step-7-production-run)
- [Step 8: Monitoring Jobs](#step-8-monitoring-jobs)
- [Step 9: Retrieving Results](#step-9-retrieving-results)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

### Deployment Workflow
```
Local Development → Docker Image → Docker Hub → Cluster → Apptainer → Slurm Jobs → Results
```

### Timeline Estimate
- **Initial Setup**: 2-3 hours (first time)
- **Smoke Test**: 15-30 minutes
- **Batch 50**: 2-3 hours
- **Production Run**: 30-50 hours (wall time, depending on job configuration)

### Resource Allocation
- **GPU**: A100 80GB nodes (high-memory queue)
- **Storage**: 5TB project allocation
- **GPU-Hours**: 1,000 hour budget

## Prerequisites

### Required Access
- [x] UIUC Campus Cluster account with active allocation
- [x] VPN access (if connecting from off-campus)
- [x] SSH key configured for cluster access
- [x] GPU allocation approved
- [x] Storage allocation (5TB) provisioned

### Required Tools
- [x] Docker Hub account (or alternative container registry)
- [x] SSH client (OpenSSH on Linux/Mac, PuTTY on Windows)
- [x] SCP/RSYNC for file transfers
- [x] Text editor for editing Slurm scripts

### Completed Local Steps
- [x] Docker image built and tested locally
- [x] Sample PDFs converted to markdown
- [x] Augmentoolkit tested with sample data
- [x] Benchmarks recorded in `docs/benchmarks.md`

⚠️ **Important**: Complete all local testing (see [docs/setup.md](setup.md)) before deploying to the cluster to avoid wasting GPU hours on debugging.

## Step 1: Campus Cluster Access

### 1.1 Request Access
If you don't have cluster access yet:
1. Visit https://campuscluster.illinois.edu/
2. Submit access request form
3. Wait for approval email (typically 1-3 business days)
4. Request GPU allocation if not included

### 1.2 Configure SSH Access
Create or update `~/.ssh/config` on your local machine:

```bash
Host cc-login
    HostName cc-login.campuscluster.illinois.edu
    User your-netid
    IdentityFile ~/.ssh/id_rsa
    ForwardAgent yes
```

### 1.3 Test Connection
```bash
ssh cc-login
```

You should see the cluster welcome message:
```
Welcome to Illinois Campus Cluster
Last login: ...
[your-netid@cc-login1 ~]$
```

### 1.4 Verify GPU Allocation
```bash
squeue -u $USER
sacctmgr show assoc user=$USER format=account,user,maxjobs,maxsubmit,grptresmins%30
```

Check for GPU hours remaining:
```bash
sreport cluster UserUtilizationByAccount Start=2025-01-01 -t hours
```

## Step 2: Container Preparation

### 2.1 Push Docker Image to Registry

On your local machine:

```bash
# Tag image for Docker Hub
docker tag mpart-augmentoolkit:v1 yourusername/mpart-augmentoolkit:v1

# Login to Docker Hub
docker login

# Push image
docker push yourusername/mpart-augmentoolkit:v1
```

Expected output:
```
The push refers to repository [docker.io/yourusername/mpart-augmentoolkit]
v1: digest: sha256:abc123... size: 4567
```

💡 **Tip**: Use version tags (v1, v2, v3) to track different configurations and allow rollbacks.

### 2.2 Pull Image on Cluster

SSH to cluster and pull the Docker image:

```bash
ssh cc-login
cd /projects/yourgroup/medicaid-qa

# Pull Docker image using Apptainer
apptainer pull docker://yourusername/mpart-augmentoolkit:v1
```

This creates: `mpart-augmentoolkit_v1.sif`

### 2.3 Verify Apptainer Image
```bash
# Check image size
ls -lh mpart-augmentoolkit_v1.sif

# Test basic command
apptainer exec mpart-augmentoolkit_v1.sif python3 --version
```

### 2.4 Test GPU Access in Apptainer

Request an interactive GPU node:
```bash
srun --account=your-account \
     --partition=gpuA100x4 \
     --gres=gpu:1 \
     --time=00:10:00 \
     --pty bash
```

Once on the GPU node:
```bash
apptainer exec --nv mpart-augmentoolkit_v1.sif nvidia-smi
```

You should see the A100 GPU details. If successful, exit the interactive session:
```bash
exit
```

## Step 3: Data Transfer

### 3.1 Create Directory Structure on Cluster

```bash
ssh cc-login
cd /projects/yourgroup/medicaid-qa

mkdir -p data/raw
mkdir -p data/processed
mkdir -p data/processed/manifests
mkdir -p data/output
mkdir -p logs
mkdir -p configs
mkdir -p scripts/slurm
```

### 3.2 Transfer Configuration Files

From your local machine:
```bash
# Transfer configs
scp configs/medicaid_config.yaml cc-login:/projects/yourgroup/medicaid-qa/configs/

# Transfer Slurm scripts
scp scripts/slurm/*.sh cc-login:/projects/yourgroup/medicaid-qa/scripts/slurm/

# Transfer test script
scp scripts/test_environment.py cc-login:/projects/yourgroup/medicaid-qa/scripts/
```

### 3.3 Transfer Processed Markdown Files

⚠️ **Important**: Transfer processed markdown files, not raw PDFs, to save time and storage.

```bash
# Transfer processed markdown (small test batch first)
rsync -avz --progress data/processed/sample/ \
  cc-login:/projects/yourgroup/medicaid-qa/data/processed/sample/
```

For larger datasets:
```bash
# Transfer all processed markdown files
rsync -avz --progress data/processed/ \
  cc-login:/projects/yourgroup/medicaid-qa/data/processed/ \
  --exclude="*.pdf"
```

### 3.4 Verify Transfer
```bash
ssh cc-login
cd /projects/yourgroup/medicaid-qa
tree -L 3 data/
```

Expected structure:
```
data/
├── processed
│   ├── sample
│   │   ├── policy_001.md
│   │   ├── policy_002.md
│   │   └── ...
│   └── manifests
└── output
```

## Step 4: Environment Setup on Cluster

### 4.1 Create Manifest Files

Manifests list which PDFs/markdown files to process in each batch.

```bash
ssh cc-login
cd /projects/yourgroup/medicaid-qa/data/processed/manifests

# Create test manifest (1 file)
ls ../sample/policy_001.md > test_single.txt

# Create small batch manifest (50 files)
ls ../sample/*.md | head -50 > batch_50.txt

# Create production manifest (all files)
ls ../*.md > production.txt
```

### 4.2 Set Up vLLM Endpoint

You have two options:

#### Option A: Request vLLM as a Service (Recommended)
Contact Campus Cluster support to request a dedicated vLLM endpoint:
```
Subject: vLLM Endpoint Request for Llama 3.1 70B
Body: Requesting a vLLM server endpoint for meta-llama/Llama-3.1-70B-Instruct
      Model for Medicaid QA generation project. Estimated usage: 1,000 GPU-hours.
```

#### Option B: Run vLLM in Separate Job
Create `scripts/slurm/vllm_server.sh`:
```bash
#!/bin/bash
#SBATCH --job-name=vllm-server
#SBATCH --account=your-account
#SBATCH --partition=gpuA100x4
#SBATCH --gres=gpu:2
#SBATCH --time=48:00:00
#SBATCH --mem=200G
#SBATCH --output=logs/vllm-%j.out

module load cuda/12.1

apptainer exec --nv mpart-augmentoolkit_v1.sif \
  python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-70B-Instruct \
  --tensor-parallel-size 2 \
  --gpu-memory-utilization 0.9 \
  --port 8000
```

Submit:
```bash
sbatch scripts/slurm/vllm_server.sh
```

💡 **Tip**: Option A is strongly recommended to avoid coordination complexity between jobs.

### 4.3 Update Slurm Scripts

Edit `scripts/slurm/test_single.sh`:

```bash
#!/bin/bash
#SBATCH --job-name=atk-test-single
#SBATCH --account=your-account-name        # ← UPDATE THIS
#SBATCH --partition=gpuA100x4              # ← Or your partition
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=00:30:00
#SBATCH --output=logs/test-single-%j.out
#SBATCH --error=logs/test-single-%j.err

# Load modules
module load cuda/12.1

# Environment variables
export LLAMA_API_KEY="your-key-or-leave-blank"
export VLLM_BASE_URL="http://your-vllm-endpoint:8000/v1"  # ← UPDATE THIS
export LLAMA_MODEL="meta-llama/Llama-3.1-70B-Instruct"

# Paths - UPDATE THESE
PROJECT_DIR="/projects/yourgroup/medicaid-qa"
CONTAINER="${PROJECT_DIR}/mpart-augmentoolkit_v1.sif"
CONFIG="${PROJECT_DIR}/configs/medicaid_config.yaml"
MANIFEST="${PROJECT_DIR}/data/processed/manifests/test_single.txt"

# Run Augmentoolkit
cd $PROJECT_DIR
apptainer exec --nv \
  --bind ${PROJECT_DIR}/data:/workspace/data \
  --bind ${PROJECT_DIR}/configs:/workspace/configs \
  --bind ${PROJECT_DIR}/logs:/workspace/logs \
  --env LLAMA_API_KEY=${LLAMA_API_KEY} \
  --env VLLM_BASE_URL=${VLLM_BASE_URL} \
  --env LLAMA_MODEL=${LLAMA_MODEL} \
  ${CONTAINER} \
  augmentoolkit --config /workspace/configs/medicaid_config.yaml

echo "Job completed at $(date)"
```

Similarly update:
- `scripts/slurm/batch_50.sh` (change time to 03:00:00)
- `scripts/slurm/production.sh` (change time to 48:00:00)

## Step 5: Smoke Testing

### 5.1 Validate Environment Script

First, run the environment test:
```bash
ssh cc-login
cd /projects/yourgroup/medicaid-qa

# Request interactive node
srun --account=your-account \
     --partition=gpuA100x4 \
     --gres=gpu:1 \
     --time=00:15:00 \
     --mem=32G \
     --pty bash

# Run environment test
apptainer exec --nv mpart-augmentoolkit_v1.sif \
  python /workspace/scripts/test_environment.py

exit  # Exit interactive session
```

### 5.2 Submit Single-PDF Test Job

```bash
sbatch scripts/slurm/test_single.sh
```

Check job status:
```bash
squeue -u $USER
```

Expected output:
```
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
12345 gpuA100x4 atk-test your-net  R       2:34      1 gpu-node-001
```

### 5.3 Monitor Test Job

```bash
# Watch output log
tail -f logs/test-single-12345.out

# Check for errors
tail -f logs/test-single-12345.err
```

### 5.4 Verify Test Results

After job completes (typically 10-15 minutes):
```bash
# Check output
ls -lh data/output/
cat data/output/dataset.jsonl | head -5

# Count QA pairs generated
wc -l data/output/dataset.jsonl
```

Expected: 5-10 QA pairs from single PDF.

⚠️ **Important**: Do not proceed to batch processing until smoke test succeeds!

## Step 6: Batch Processing

### 6.1 Batch 50 PDFs

Once smoke test succeeds, scale to 50 PDFs:

```bash
sbatch scripts/slurm/batch_50.sh
```

Monitor job:
```bash
squeue -u $USER
watch -n 60 'squeue -u $USER'  # Auto-refresh every 60 seconds
```

### 6.2 Track GPU Usage

```bash
# Check GPU hours used so far
sreport cluster UserUtilizationByAccount Start=$(date -d "7 days ago" +%Y-%m-%d) End=$(date +%Y-%m-%d) -t hours
```

### 6.3 Validate Batch 50 Results

After completion (2-4 hours):
```bash
# Count outputs
wc -l data/output/dataset.jsonl

# Sample quality check
cat data/output/dataset.jsonl | jq -r '.question' | head -20
```

Expected: ~250 QA pairs (5 per PDF × 50 PDFs)

### 6.4 Review and Adjust

Before scaling further:
1. Manually review 10-20 random QA pairs for quality
2. Check GPU utilization in logs
3. Estimate total GPU hours for 1,100 PDFs
4. Adjust config if needed (`system.concurrency_limit`, `chunk_size`)

## Step 7: Production Run

### 7.1 Prepare Production Manifest

```bash
cd /projects/yourgroup/medicaid-qa/data/processed/manifests

# List all processed markdown files
find ../  -name "*.md" -type f > production.txt

# Verify count
wc -l production.txt
```

Expected: ~1,100 lines

### 7.2 Update Production Script

Edit `scripts/slurm/production.sh`:
- Set `--time=48:00:00` (or higher if needed)
- Set `--mem=128G`
- Ensure manifest points to `production.txt`

### 7.3 Submit Production Job

```bash
sbatch scripts/slurm/production.sh
```

Record job ID:
```bash
PROD_JOB_ID=$(squeue -u $USER -o "%A" --noheader | head -1)
echo "Production Job ID: $PROD_JOB_ID"
```

### 7.4 Set Up Job Arrays (Optional)

For better parallelism and fault tolerance, split into job arrays:

```bash
# Split manifest into chunks of 100
cd data/processed/manifests
split -l 100 production.txt production_batch_ -d -a 2
```

This creates:
- `production_batch_00` (100 files)
- `production_batch_01` (100 files)
- ...
- `production_batch_10` (100 files)

Update `scripts/slurm/production.sh` to use `--array=0-10`:
```bash
#SBATCH --array=0-10
...
MANIFEST="${PROJECT_DIR}/data/processed/manifests/production_batch_$(printf "%02d" $SLURM_ARRAY_TASK_ID)"
```

Submit array:
```bash
sbatch scripts/slurm/production.sh
```

## Step 8: Monitoring Jobs

### 8.1 Check Job Status

```bash
# List your jobs
squeue -u $USER

# Detailed job info
scontrol show job JOBID

# Check job array status
squeue -u $USER --array
```

### 8.2 Monitor Resource Usage

```bash
# GPU utilization (while job is running)
srun --jobid JOBID nvidia-smi

# Memory usage
sstat --format=JobID,MaxRSS,AveCPU -j JOBID

# GPU hours consumed
seff JOBID  # After job completes
```

### 8.3 Live Log Monitoring

```bash
# Production job output
tail -f logs/production-JOBID.out

# Error log
tail -f logs/production-JOBID.err

# Search for errors
grep -i "error" logs/production-JOBID.err
```

### 8.4 Email Notifications

Add to Slurm script header:
```bash
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=your-email@illinois.edu
```

### 8.5 Handling Job Failures

If a job fails:
```bash
# Check failure reason
scontrol show job JOBID | grep -i reason

# View error log
cat logs/production-JOBID.err

# Resume from last checkpoint (if Augmentoolkit supports it)
# Edit config to skip processed files, then resubmit
sbatch scripts/slurm/production.sh
```

## Step 9: Retrieving Results

### 9.1 Verify Completion

```bash
ssh cc-login
cd /projects/yourgroup/medicaid-qa

# Check output files
ls -lh data/output/

# Count total QA pairs
wc -l data/output/dataset.jsonl
```

Expected: ~5,500 QA pairs

### 9.2 Validate Output Quality

```bash
# Sample random QA pairs
shuf -n 20 data/output/dataset.jsonl | jq -r '[.id, .question, .answer] | @tsv'

# Check for errors in metadata
cat data/output/dataset.jsonl | jq -r '.metadata.errors' | grep -v "null"
```

### 9.3 Transfer Results to Local Machine

From your local machine:
```bash
# Transfer output files
rsync -avz --progress \
  cc-login:/projects/yourgroup/medicaid-qa/data/output/ \
  ./data/output/

# Transfer logs for analysis
rsync -avz --progress \
  cc-login:/projects/yourgroup/medicaid-qa/logs/ \
  ./logs/
```

### 9.4 Create Dataset Splits

On local machine or cluster:
```bash
python3 <<EOF
import json
import random

# Load dataset
with open('data/output/dataset.jsonl', 'r') as f:
    data = [json.loads(line) for line in f]

# Shuffle
random.seed(42)
random.shuffle(data)

# Split: 80% train, 10% val, 10% test
total = len(data)
train_size = int(0.8 * total)
val_size = int(0.1 * total)

train_data = data[:train_size]
val_data = data[train_size:train_size+val_size]
test_data = data[train_size+val_size:]

# Save splits
with open('data/output/train.jsonl', 'w') as f:
    for item in train_data:
        f.write(json.dumps(item) + '\n')

with open('data/output/val.jsonl', 'w') as f:
    for item in val_data:
        f.write(json.dumps(item) + '\n')

with open('data/output/test.jsonl', 'w') as f:
    for item in test_data:
        f.write(json.dumps(item) + '\n')

print(f"Train: {len(train_data)}, Val: {len(val_data)}, Test: {len(test_data)}")
EOF
```

### 9.5 Update Documentation

Record final metrics in `docs/benchmarks.md`:
- Total PDFs processed
- Total QA pairs generated
- Total GPU hours used
- Average time per PDF
- Output file sizes

## Troubleshooting

### Job stays in pending state (PD)
**Check**: `squeue -u $USER`
**Reason**: Typically resource unavailability or queue priority
**Solution**: 
```bash
# Check detailed reason
squeue -u $USER --start

# Reduce resource requirements or wait
```

### Job fails immediately after starting
**Check**: Error log
```bash
cat logs/production-JOBID.err
```
**Common causes**:
- Incorrect paths in script
- Missing environment variables
- Apptainer binding issues

**Solution**: Fix paths/variables and resubmit

### Apptainer: "could not open image"
**Solution**: Check image path and permissions
```bash
ls -l mpart-augmentoolkit_v1.sif
# Should be readable by your user
```

### GPU not accessible in Apptainer
**Solution**: Ensure `--nv` flag is used:
```bash
apptainer exec --nv mpart-augmentoolkit_v1.sif nvidia-smi
```

### Out of memory error
**Solution**: Increase memory allocation:
```bash
#SBATCH --mem=256G  # Increase from 128G
```

Or reduce concurrency in config:
```yaml
system:
  concurrency_limit: 20  # Reduce from 50
```

### Cannot connect to vLLM endpoint
**Check**: 
```bash
curl http://your-vllm-endpoint:8000/v1/models
```
**Solution**: Verify vLLM server is running and accessible from compute nodes

For more issues, see [docs/troubleshooting.md](troubleshooting.md)

## Best Practices

### Resource Management
1. **Start small**: Always test with 1 → 50 → 200 → 500 → full dataset
2. **Monitor GPU hours**: Check usage after each batch to avoid overruns
3. **Use job arrays**: Better fault tolerance and parallelism than single large jobs
4. **Set time limits conservatively**: 48 hours for production, but expect 30-40 hours

### Data Management
1. **Backup manifests**: Keep copies of all manifest files
2. **Version outputs**: Tag output directories with dates/versions
3. **Clean up intermediate files**: Remove temporary files after validation
4. **Document processing**: Keep notes on which batches have been processed

### Job Optimization
1. **Use high-memory nodes**: A100 80GB nodes are optimal for Llama 70B
2. **Checkpoint regularly**: If Augmentoolkit supports it, enable checkpointing
3. **Log verbosely**: Better to have too much logging than too little
4. **Test config changes locally first**: Don't waste GPU hours debugging on cluster

### Collaboration
1. **Communicate with team**: Use Slack to coordinate cluster usage
2. **Share logs**: Keep team updated on progress and issues
3. **Document decisions**: Record why certain parameters were chosen
4. **Track GPU hours**: Maintain shared spreadsheet of usage

---

## Next Steps

After successful deployment:

1. **Quality Assurance**: Manually review 100+ random QA pairs
2. **Dataset Finalization**: Create train/val/test splits and document
3. **Documentation**: Update [docs/benchmarks.md](benchmarks.md) with final metrics
4. **Dataset Card**: Complete [docs/dataset_card.md](dataset_card.md) with statistics
5. **Team Handoff**: Prepare materials for team presentation

---

**Questions?** 
- Cluster issues: Contact help@campuscluster.illinois.edu
- Pipeline issues: See [docs/troubleshooting.md](troubleshooting.md)
- Team questions: Slack #medicaid-qa

**Previous Step**: [docs/setup.md](setup.md) - Local Development Setup
**Next Step**: [docs/workflow.md](workflow.md) - Complete Processing Workflow
