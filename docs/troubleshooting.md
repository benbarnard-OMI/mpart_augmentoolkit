# Troubleshooting Guide

> **Last Updated**: 2025-11-04

This guide provides solutions to common issues encountered during local development and cluster deployment of the MPART Augmentoolkit project.

## Quick Reference

- **Slack Channel**: `#medicaid-qa`
- **Campus Cluster Help Desk**: help@campuscluster.illinois.edu
- **Primary Contacts**: Ben Barnard (lead)
- **Emergency Escalation**: If blocked >12 hours, escalate to team lead

## Table of Contents

- [Docker and Container Issues](#docker-and-container-issues)
- [GPU Access Problems](#gpu-access-problems)
- [Augmentoolkit Configuration Errors](#augmentoolkit-configuration-errors)
- [Slurm Job Failures](#slurm-job-failures)
- [Memory Issues](#memory-issues)
- [Data Format and Conversion Issues](#data-format-and-conversion-issues)
- [Network and API Issues](#network-and-api-issues)
- [Performance Issues](#performance-issues)
- [Escalation Procedures](#escalation-procedures)

---

## Docker and Container Issues

### Issue: Docker build fails with "No space left on device"

**Symptoms:**
```
ERROR: failed to solve: write /var/lib/docker/...: no space left on device
```

**Likely Cause:** Docker's disk space is full from old images/containers/volumes.

**Solution:**
```bash
# Check disk usage
docker system df

# Clean up unused resources
docker system prune -a --volumes

# Verify space freed
df -h /var/lib/docker
```

**Verification:**
Rebuild should complete without errors.

---

### Issue: `nvidia-smi` not available inside container

**Symptoms:**
```
nvidia-smi: command not found
```
OR
```
NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver
```

**Likely Cause:** Container not started with GPU access flags.

**Solution for Docker:**
```bash
# Correct command with --gpus all flag
docker run --gpus all mpart-augmentoolkit:v1 nvidia-smi
```

**Solution for Apptainer:**
```bash
# Correct command with --nv flag
apptainer exec --nv mpart-augmentoolkit_v1.sif nvidia-smi
```

**Verification:**
Should display GPU information without errors.

---

### Issue: Python package import errors

**Symptoms:**
```
ImportError: cannot import name 'X' from 'module'
ModuleNotFoundError: No module named 'package'
```

**Likely Cause:** 
- Outdated Docker image
- Missing dependencies in requirements.txt
- Version conflicts

**Solution:**
```bash
# Rebuild image from scratch (no cache)
docker build --no-cache -t mpart-augmentoolkit:v1 .

# If specific package is missing, add to requirements.txt and rebuild
echo "missing-package==1.0.0" >> requirements.txt
docker build -t mpart-augmentoolkit:v1 .
```

**Verification:**
```bash
docker run --gpus all mpart-augmentoolkit:v1 python3 -c "import package_name; print('Success')"
```

---

### Issue: Apptainer "could not open image" error

**Symptoms:**
```
FATAL: could not open image mpart-augmentoolkit_v1.sif: image format not recognized
```

**Likely Cause:** 
- Incomplete image pull
- Corrupted .sif file
- Wrong file path

**Solution:**
```bash
# Remove corrupted image
rm mpart-augmentoolkit_v1.sif

# Re-pull from Docker Hub
apptainer pull docker://yourusername/mpart-augmentoolkit:v1

# Verify image integrity
apptainer inspect mpart-augmentoolkit_v1.sif
```

**Verification:**
```bash
apptainer exec mpart-augmentoolkit_v1.sif python3 --version
```

---

## GPU Access Problems

### Issue: CUDA out of memory

**Symptoms:**
```
torch.cuda.OutOfMemoryError: CUDA out of memory
RuntimeError: CUDA error: out of memory
```

**Likely Cause:** 
- Model too large for available VRAM
- Batch size too large
- Memory leak from previous runs

**Solution:**

**Option 1: Reduce batch size/concurrency**
```yaml
# In configs/medicaid_config.yaml
system:
  concurrency_limit: 20  # Reduce from 50
```

**Option 2: Use gradient checkpointing**
```yaml
# Enable if supported by Augmentoolkit
model_training:
  gradient_checkpointing: true
```

**Option 3: Clear GPU cache**
```bash
# In Python script
import torch
torch.cuda.empty_cache()
```

**Option 4: Use smaller model for testing**
```bash
export LLAMA_MODEL="meta-llama/Llama-3.1-8B-Instruct"  # Instead of 70B
```

**Verification:**
```bash
# Monitor GPU memory usage
nvidia-smi -l 1  # Updates every second
```

---

### Issue: GPU not detected by PyTorch

**Symptoms:**
```python
torch.cuda.is_available()  # Returns False
```

**Likely Cause:**
- CUDA version mismatch
- PyTorch not compiled with CUDA support
- Driver issues

**Solution:**
```bash
# Check CUDA version
nvidia-smi | grep "CUDA Version"

# Verify PyTorch CUDA support
docker run --gpus all mpart-augmentoolkit:v1 python3 -c "import torch; print(f'PyTorch CUDA: {torch.version.cuda}'); print(f'CUDA Available: {torch.cuda.is_available()}')"

# If mismatch, reinstall PyTorch with correct CUDA version
# Edit requirements.txt or Dockerfile:
# torch>=2.0.0+cu121
```

**Verification:**
```python
import torch
print(torch.cuda.is_available())  # Should return True
print(torch.cuda.device_count())  # Should show GPU count
```

---

### Issue: vLLM fails to initialize

**Symptoms:**
```
ValueError: Model is too large for available GPU memory
RuntimeError: Cannot initialize CUDA context
```

**Likely Cause:**
- Insufficient VRAM for model
- Incorrect tensor parallelism settings

**Solution:**
```bash
# For Llama 3.1 70B, use tensor parallelism
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-70B-Instruct \
  --tensor-parallel-size 2 \
  --gpu-memory-utilization 0.85 \
  --max-model-len 4096

# If still fails, use quantization
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-70B-Instruct \
  --quantization awq \
  --tensor-parallel-size 2
```

**Verification:**
```bash
curl http://localhost:8000/v1/models
```

---

## Augmentoolkit Configuration Errors

### Issue: Configuration file validation fails

**Symptoms:**
```
yaml.scanner.ScannerError: while scanning a simple key
ValueError: Invalid configuration key: 'xyz'
```

**Likely Cause:**
- YAML syntax error (indentation, colons, quotes)
- Invalid configuration values
- Missing required fields

**Solution:**
```bash
# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('configs/medicaid_config.yaml'))"

# Check for tabs (YAML requires spaces)
grep -P '\t' configs/medicaid_config.yaml

# Use a YAML linter
yamllint configs/medicaid_config.yaml
```

**Verification:**
Configuration should load without errors.

---

### Issue: Environment variables not recognized

**Symptoms:**
```
KeyError: 'LLAMA_API_KEY'
Configuration value ${LLAMA_API_KEY} not resolved
```

**Likely Cause:** Environment variables not passed to container.

**Solution for Docker:**
```bash
docker run --gpus all \
  -e LLAMA_API_KEY="${LLAMA_API_KEY}" \
  -e VLLM_BASE_URL="${VLLM_BASE_URL}" \
  -e LLAMA_MODEL="${LLAMA_MODEL}" \
  mpart-augmentoolkit:v1 augmentoolkit --config /workspace/configs/medicaid_config.yaml
```

**Solution for Apptainer:**
```bash
apptainer exec --nv \
  --env LLAMA_API_KEY="${LLAMA_API_KEY}" \
  --env VLLM_BASE_URL="${VLLM_BASE_URL}" \
  mpart-augmentoolkit_v1.sif augmentoolkit --config /workspace/configs/medicaid_config.yaml
```

**Verification:**
```bash
# Verify environment variables inside container
docker run --gpus all -e LLAMA_API_KEY="test" mpart-augmentoolkit:v1 env | grep LLAMA_API_KEY
```

---

### Issue: Augmentoolkit run halts without error

**Symptoms:**
- Process stops mid-execution
- No error messages in logs
- Last log entry shows normal operation

**Likely Cause:**
- Silent timeout
- API rate limiting
- Network interruption

**Solution:**
```bash
# Enable verbose logging
# Add to medicaid_config.yaml:
system:
  log_level: DEBUG

# Check for rate limiting
grep -i "rate limit" logs/latest.log

# Reduce concurrency to avoid rate limits
system:
  concurrency_limit: 10  # Reduce from 50
```

**Verification:**
Check logs for completion message or specific error.

---

## Slurm Job Failures

### Issue: Job pending indefinitely

**Symptoms:**
```bash
squeue -u $USER
# Shows state: PD (Pending)
```

**Likely Cause:**
- Resource unavailability (no free GPUs)
- Queue priority
- Exceeded job limits

**Solution:**
```bash
# Check detailed reason
squeue -u $USER --start

# Check your job limits
sacctmgr show assoc user=$USER format=account,user,maxjobs

# Reduce resource requirements
#SBATCH --gres=gpu:1      # Instead of gpu:2
#SBATCH --time=24:00:00   # Instead of 48:00:00

# Try different partition
#SBATCH --partition=gpuA100x2  # Instead of gpuA100x4
```

**Verification:**
Job should transition from PD to R (Running).

---

### Issue: Job fails immediately after starting

**Symptoms:**
```bash
squeue -u $USER
# Job disappears immediately or shows state: F (Failed)
```

**Likely Cause:**
- Incorrect paths
- Missing files
- Permission issues
- Module load failures

**Solution:**
```bash
# Check error log
cat logs/job-name-JOBID.err

# Common fixes:
# 1. Fix paths in Slurm script
PROJECT_DIR="/projects/yourgroup/medicaid-qa"  # Update this

# 2. Load required modules
module load cuda/12.1

# 3. Verify file permissions
ls -la mpart-augmentoolkit_v1.sif

# 4. Test interactively first
srun --account=your-account --partition=gpuA100x4 --gres=gpu:1 --time=00:30:00 --pty bash
# Then run commands manually to debug
```

**Verification:**
Job should run for more than a few seconds.

---

### Issue: Job killed by scheduler (OUT_OF_MEMORY)

**Symptoms:**
```
slurmstepd: error: Detected X oom-kill event(s)
slurmstepd: error: Exceeded job memory limit
```

**Likely Cause:**
- Insufficient memory allocation
- Memory leak
- Inefficient processing

**Solution:**
```bash
# Increase memory allocation in Slurm script
#SBATCH --mem=256G  # Increase from 128G

# Or reduce concurrency in config
system:
  concurrency_limit: 20  # Reduce from 50

# Check actual memory usage from previous run
sstat --format=JobID,MaxRSS -j JOBID
```

**Verification:**
```bash
# Monitor memory during job
sstat --format=JobID,MaxRSS -j JOBID
```

---

### Issue: Job exceeds time limit

**Symptoms:**
```
slurmstepd: error: *** JOB X ON node CANCELLED AT ... DUE TO TIME LIMIT ***
```

**Likely Cause:**
- Processing slower than expected
- Inefficient configuration

**Solution:**
```bash
# Increase time limit
#SBATCH --time=72:00:00  # Increase from 48:00:00

# Or optimize processing:
# 1. Increase concurrency
system:
  concurrency_limit: 50  # Increase from 20

# 2. Use job arrays to parallelize
#SBATCH --array=0-10
```

**Verification:**
Monitor job progress and estimate completion time.

---

## Memory Issues

### Issue: System runs out of RAM

**Symptoms:**
```
MemoryError: Unable to allocate array
Killed (out of memory)
```

**Likely Cause:**
- Loading too much data at once
- Inefficient data structures
- Memory leak

**Solution:**
```bash
# Reduce chunk size
system:
  chunk_size: 1000  # Reduce from 1500

# Process in smaller batches
# Split manifest into smaller files

# Enable garbage collection in Python
import gc
gc.collect()

# Limit cache size
export HF_HOME="/path/with/more/space"
export TRANSFORMERS_CACHE="/path/with/more/space"
```

**Verification:**
```bash
# Monitor memory usage
htop  # On local machine
sstat --format=JobID,MaxRSS -j JOBID  # On cluster
```

---

## Data Format and Conversion Issues

### Issue: Markdown output missing sections

**Symptoms:**
- Converted markdown has gaps
- Missing tables or lists
- Incomplete sections

**Likely Cause:**
- Docling conversion errors
- PDF formatting issues
- OCR failures (for scanned PDFs)

**Solution:**
```bash
# Check Docling logs
cat data/processed/logs/conversion.log

# Try different conversion settings
python scripts/preprocessing/convert_pdfs.py \
  --input-dir data/raw \
  --output-dir data/processed \
  --ocr-enabled  # For scanned PDFs

# For critical documents, manual review and correction may be needed
```

**Verification:**
Compare markdown output with original PDF visually.

---

### Issue: Encoding errors during conversion

**Symptoms:**
```
UnicodeDecodeError: 'utf-8' codec can't decode byte
UnicodeEncodeError: 'ascii' codec can't encode character
```

**Likely Cause:**
- Non-UTF-8 encoded files
- Special characters in PDFs

**Solution:**
```python
# In convert_pdfs.py, add encoding handling:
with open(output_file, 'w', encoding='utf-8', errors='ignore') as f:
    f.write(markdown_content)

# Or sanitize PDFs first
pdftk input.pdf output output.pdf compress
```

**Verification:**
```bash
file -i data/processed/sample/*.md  # Should show utf-8
```

---

### Issue: QA pairs have poor quality

**Symptoms:**
- Questions are vague or irrelevant
- Answers don't match questions
- Source citations missing

**Likely Cause:**
- Poor markdown input quality
- Inappropriate model parameters
- Insufficient context in chunks

**Solution:**
```yaml
# Increase chunk size for more context
system:
  chunk_size: 2000  # Increase from 1500

# Enable answer accuracy checks
factual_sft:
  openended:
    skip_answer_accuracy_check: False  # Enable validation
    skip_repair_qa_tuples: False       # Enable repair

# Adjust shared instruction for better prompting
system:
  shared_instruction: |
    Your updated instruction with more specific guidance...
```

**Verification:**
Manually review 20-30 generated QA pairs.

---

## Network and API Issues

### Issue: Cannot connect to vLLM endpoint

**Symptoms:**
```
requests.exceptions.ConnectionError: Failed to establish connection
Connection refused
```

**Likely Cause:**
- vLLM server not running
- Wrong endpoint URL
- Firewall blocking connection
- Network issues between container and host

**Solution:**
```bash
# Verify vLLM server is running
curl http://localhost:8000/v1/models

# Use --network host for Docker
docker run --gpus all --network host ...

# Check firewall rules
sudo ufw status

# For cluster, verify endpoint is accessible from compute nodes
srun --account=your-account --partition=gpuA100x4 --gres=gpu:1 --time=00:05:00 curl http://vllm-endpoint:8000/v1/models
```

**Verification:**
```bash
curl http://your-vllm-endpoint:8000/v1/models
# Should return JSON with model info
```

---

### Issue: API rate limiting

**Symptoms:**
```
Error 429: Too Many Requests
Rate limit exceeded
```

**Likely Cause:** Too many concurrent requests to API.

**Solution:**
```yaml
# Reduce concurrency
system:
  concurrency_limit: 10  # Reduce from 50

# Add retry logic (if supported by Augmentoolkit)
api:
  max_retries: 5
  retry_delay: 2
```

**Verification:**
Monitor API usage and adjust concurrency accordingly.

---

## Performance Issues

### Issue: Processing is very slow

**Symptoms:**
- Taking >10 minutes per PDF
- Low GPU utilization (<30%)

**Likely Cause:**
- Low concurrency
- API bottleneck
- Inefficient configuration

**Solution:**
```yaml
# Increase concurrency
system:
  concurrency_limit: 50  # Increase from 20

# Check GPU utilization
nvidia-smi dmon -s u

# If GPU utilization is low, increase batch size or concurrency
# If GPU utilization is high, you're at capacity
```

**Verification:**
```bash
# Monitor processing rate
tail -f logs/latest.log | grep "Processed"
```

---

### Issue: Inconsistent processing times

**Symptoms:**
- Some PDFs process in 2 minutes
- Others take 20+ minutes

**Likely Cause:**
- Variable PDF length/complexity
- Chunk size mismatch

**Solution:**
This is expected behavior. Consider:
```bash
# Split processing by PDF size
ls -lh data/raw/ | sort -k5 -h  # Sort by file size

# Process large and small PDFs in separate batches
```

**Verification:**
Track time-per-PDF and identify outliers for manual review.

---

## Escalation Procedures

### When to Escalate

Escalate issues when:
1. **Blocked >12 hours** without resolution
2. **Cluster-wide issues** (multiple users affected)
3. **Data loss or corruption**
4. **Security concerns**
5. **GPU hour budget exceeded**

### Escalation Steps

1. **Document the issue**:
   ```bash
   # Collect relevant information
   - Job ID
   - Error messages from logs
   - Steps to reproduce
   - Configuration files used
   - Troubleshooting steps already attempted
   ```

2. **Notify team on Slack** (#medicaid-qa):
   ```
   🚨 Issue: [Brief description]
   Status: Blocked for X hours
   Job ID: XXXXXX
   Error: [Key error message]
   Attempted: [Troubleshooting steps tried]
   Next: Escalating to [cluster support / team lead]
   ```

3. **Contact Campus Cluster Support**:
   ```
   To: help@campuscluster.illinois.edu
   Subject: [URGENT] GPU Job Failure - Project: Medicaid QA
   
   Job ID: XXXXXX
   Account: your-account
   Issue: [Detailed description]
   Error logs: [Attach .err file]
   Slurm script: [Attach .sh file]
   Troubleshooting attempted: [List steps]
   ```

4. **Update issue log**:
   - Add entry to this document's Lessons Learned section
   - Document resolution for future reference

---

## Lessons Learned

### Recurring Issues Log

| Date | Issue | Resolution | Owner | Prevention |
|------|-------|------------|-------|------------|
| _TBD_ | _To be filled during project_ | _Solution_ | _Name_ | _How to avoid_ |

### Best Practices Discovered

_Document best practices as you discover them during the project_

---

## Additional Resources

- **Augmentoolkit Documentation**: https://github.com/e-p-armstrong/augmentoolkit
- **vLLM Documentation**: https://docs.vllm.ai/
- **Campus Cluster Wiki**: https://campuscluster.illinois.edu/resources/docs/
- **Docker Best Practices**: https://docs.docker.com/develop/dev-best-practices/
- **Slurm Documentation**: https://slurm.schedmd.com/documentation.html

---

**Need more help?**
- Check [docs/setup.md](setup.md) for local setup issues
- Check [docs/campus_cluster_deployment.md](campus_cluster_deployment.md) for cluster issues
- Post in Slack #medicaid-qa for team assistance
- Email help@campuscluster.illinois.edu for cluster issues
