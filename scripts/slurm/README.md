# Augmentoolkit Slurm Scripts for UIUC Campus Cluster

This directory contains SLURM batch job scripts for running the Augmentoolkit pipeline on the UIUC Campus Cluster's GPU nodes.

## Overview

These scripts are designed to process Medicaid policy PDFs through the Augmentoolkit pipeline using NVIDIA A100 GPUs on the IllinoisComputes-GPU partition.

## Prerequisites

1. **Access to UIUC Campus Cluster**
   - Account: `bbarn4-ic`
   - Partition: `IllinoisComputes-GPU`
   - GPU allocation: 1,000 GPU-hours

2. **Container Image**
   - Docker image converted to Apptainer/Singularity format
   - Should be stored on the cluster filesystem
   - Default location: `/projects/bbarn4-ic/containers/augmentoolkit-pipeline_latest.sif`

3. **Data Files**
   - Processed PDF files (converted to markdown)
   - Located at: `/projects/bbarn4-ic/medicaid/data/processed/`
   - Manifest files listing PDFs to process

4. **Required Modules**
   - Apptainer (Singularity) - available via `module load apptainer/latest`

## Converting Docker Image to Apptainer Format

Before running any jobs, you need to convert your Docker image to Apptainer's `.sif` format:

### Option 1: From Docker Hub (if image is pushed)

```bash
# SSH to Campus Cluster
ssh <netid>@cc-login.campuscluster.illinois.edu

# Navigate to containers directory
cd /projects/bbarn4-ic/containers

# Load Apptainer module
module load apptainer/latest

# Pull and convert from Docker Hub
apptainer pull augmentoolkit-pipeline_latest.sif docker://your-dockerhub-username/augmentoolkit-pipeline:latest
```

### Option 2: From Docker Save File

```bash
# On your local machine (where Docker is running):
docker save augmentoolkit-pipeline:latest -o augmentoolkit-pipeline.tar

# Transfer to cluster
scp augmentoolkit-pipeline.tar <netid>@cc-login.campuscluster.illinois.edu:/projects/bbarn4-ic/containers/

# On the cluster:
ssh <netid>@cc-login.campuscluster.illinois.edu
cd /projects/bbarn4-ic/containers
module load apptainer/latest

# Convert tar to sif
apptainer build augmentoolkit-pipeline_latest.sif docker-archive://augmentoolkit-pipeline.tar

# Clean up tar file (optional)
rm augmentoolkit-pipeline.tar
```

### Option 3: From Local Docker Daemon (if Docker is installed on cluster)

```bash
apptainer build augmentoolkit-pipeline_latest.sif docker-daemon://augmentoolkit-pipeline:latest
```

### Verify the Container

```bash
# Test that the container works
apptainer exec augmentoolkit-pipeline_latest.sif python --version

# Test with GPU support
apptainer exec --nv augmentoolkit-pipeline_latest.sif nvidia-smi
```

## Directory Structure

Before running jobs, create this directory structure on the cluster:

```
/projects/bbarn4-ic/medicaid/
├── containers/
│   └── augmentoolkit-pipeline_latest.sif    # Apptainer container
├── data/
│   ├── processed/                           # Input: processed markdown files
│   │   └── manifests/                       # Manifest files listing PDFs
│   │       ├── batch_50.list               # List of 50 PDFs for testing
│   │       └── production.list             # List of all PDFs for production
│   ├── output/                              # Output: generated QA datasets
│   └── raw/                                 # Original PDF files (optional)
├── logs/                                    # Slurm job logs
└── configs/                                 # Configuration files (if not in container)
```

Create the structure:

```bash
# From your home directory on the cluster
cd /projects/bbarn4-ic/medicaid

# Create directories
mkdir -p containers
mkdir -p data/processed/manifests
mkdir -p data/output
mkdir -p logs

# Copy your repository logs directory structure too
cd /path/to/your/cloned/repo
mkdir -p logs
```

## Creating Manifest Files

Manifest files are text files with one PDF path per line:

```bash
# Create a manifest of all PDFs in processed directory
find /projects/bbarn4-ic/medicaid/data/processed -name "*.pdf" -type f > \
  /projects/bbarn4-ic/medicaid/data/processed/manifests/production.list

# Create a small test manifest (first 50 files)
head -n 50 /projects/bbarn4-ic/medicaid/data/processed/manifests/production.list > \
  /projects/bbarn4-ic/medicaid/data/processed/manifests/batch_50.list

# Create a single-file manifest for testing
head -n 1 /projects/bbarn4-ic/medicaid/data/processed/manifests/production.list > \
  /projects/bbarn4-ic/medicaid/data/processed/manifests/single.list
```

## Scripts Description

### 1. `test_environment.sh` - Environment Validation

**Purpose:** Verify that the container and GPU environment work correctly.

**Resources:**
- 1 GPU
- 4 CPUs
- 32GB RAM
- 10 minutes

**Usage:**
```bash
sbatch scripts/slurm/test_environment.sh
```

**What it does:**
- Loads Apptainer module
- Runs `test_environment.py` to verify Python, dependencies, and GPU access
- Validates the container environment

**When to use:** This is the FIRST script you should run on the cluster.

---

### 2. `test_single_pdf.sh` - Single PDF Test

**Purpose:** Process exactly one PDF through the complete pipeline.

**Resources:**
- 1 GPU
- 8 CPUs
- 128GB RAM
- 2 hours

**Usage:**
```bash
# Use defaults (requires setting defaults in script)
sbatch scripts/slurm/test_single_pdf.sh

# Specify run ID and PDF path
sbatch scripts/slurm/test_single_pdf.sh test-run-01 /projects/bbarn4-ic/medicaid/data/processed/sample.pdf
```

**What it does:**
- Processes a single PDF through the full Augmentoolkit pipeline
- Generates QA pairs for one document
- Validates the complete workflow

**When to use:** After `test_environment.sh` succeeds, run this to verify the full pipeline.

---

### 3. `batch_small.sh` - Small Batch (50 PDFs)

**Purpose:** Process 50 PDFs to validate scalability and estimate resource needs.

**Resources:**
- 1 GPU
- 16 CPUs
- 256GB RAM
- 8 hours

**Usage:**
```bash
# Use defaults
sbatch scripts/slurm/batch_small.sh

# Specify run ID and manifest
sbatch scripts/slurm/batch_small.sh batch-50-test /projects/bbarn4-ic/medicaid/data/processed/manifests/batch_50.list
```

**What it does:**
- Processes up to 50 PDFs
- Provides performance metrics for estimating full production time
- Calculates GPU-hours needed for complete dataset

**When to use:** After single PDF test succeeds, run this to gauge production requirements.

---

### 4. `production.sh` - Full Production Run

**Purpose:** Process all PDFs (up to 1,100) for production dataset generation.

**Resources:**
- 2 GPUs (adjustable)
- 32 CPUs
- 512GB RAM
- 48 hours

**Usage:**
```bash
# Use defaults
sbatch scripts/slurm/production.sh

# Specify run ID and manifest
sbatch scripts/slurm/production.sh prod-2025-11-04 /projects/bbarn4-ic/medicaid/data/processed/manifests/production.list
```

**What it does:**
- Processes complete dataset
- Includes checkpoint/resume capability
- Robust error handling
- Progress tracking

**When to use:** After batch test succeeds and you've reviewed performance metrics.

---

## Customizing the Scripts

Before running, update these variables in each script:

```bash
# Container location
CONTAINER_IMAGE="/projects/bbarn4-ic/containers/augmentoolkit-pipeline_latest.sif"

# Data directory
DATA_DIR="/projects/bbarn4-ic/medicaid/data"

# Configuration file (inside container)
CONFIG_FILE="/workspace/configs/medicaid_config.yaml"
```

## Slurm Commands Reference

### Submitting Jobs

```bash
# Submit a job
sbatch scripts/slurm/test_environment.sh

# Submit with custom parameters
sbatch scripts/slurm/test_single_pdf.sh my-run-id /path/to/file.pdf
```

### Monitoring Jobs

```bash
# Check your job queue
squeue -u $USER

# Check specific job
squeue -j <job-id>

# Watch queue in real-time
watch -n 5 squeue -u $USER

# Get detailed job info
scontrol show job <job-id>
```

### Viewing Logs

```bash
# View output log (while running or after completion)
tail -f logs/test-env-<job-id>.out

# View error log
tail -f logs/test-env-<job-id>.err

# View completed job logs
less logs/production-<job-id>.out
```

### Managing Jobs

```bash
# Cancel a job
scancel <job-id>

# Cancel all your jobs
scancel -u $USER

# Hold a job (prevent it from starting)
scontrol hold <job-id>

# Release a held job
scontrol release <job-id>
```

### Job History and Accounting

```bash
# View completed jobs
sacct -u $USER

# Detailed job info
sacct -j <job-id> --format=JobID,JobName,State,Elapsed,MaxRSS,MaxVMSize

# Job efficiency report
seff <job-id>

# Check GPU hours used
sacct -j <job-id> --format=JobID,AllocGRES,Elapsed
```

## Workflow: Running Your First Job

Follow this sequence to ensure everything works:

### Step 1: Prepare the Environment

```bash
# SSH to cluster
ssh <netid>@cc-login.campuscluster.illinois.edu

# Navigate to your project
cd /projects/bbarn4-ic/medicaid

# Clone your repository if not already done
git clone <your-repo-url> repo
cd repo

# Make scripts executable
chmod +x scripts/slurm/*.sh

# Create logs directory
mkdir -p logs
```

### Step 2: Environment Test

```bash
# Submit environment validation test
sbatch scripts/slurm/test_environment.sh

# Monitor the job
watch -n 5 squeue -u $USER

# Once complete, check the logs
cat logs/test-env-<job-id>.out
```

**Expected result:** All environment checks should pass, GPU should be detected.

### Step 3: Single PDF Test

```bash
# Submit single PDF test
sbatch scripts/slurm/test_single_pdf.sh

# Monitor progress
tail -f logs/single-pdf-<job-id>.out

# After completion, review outputs
ls -lh /projects/bbarn4-ic/medicaid/data/output/test_single_*/
```

**Expected result:** QA pairs generated for one PDF, no errors.

### Step 4: Small Batch Test

```bash
# Submit 50-PDF batch
sbatch scripts/slurm/batch_small.sh

# Monitor (this will take several hours)
tail -f logs/batch-50-<job-id>.out

# Check progress periodically
squeue -j <job-id>
```

**Expected result:** 
- Performance metrics showing PDFs/hour
- Estimated time for full production
- GPU-hours estimate

### Step 5: Review and Plan

```bash
# Review batch results
less logs/batch-50-<job-id>.out

# Look at the performance metrics at the end
# Calculate if you have enough GPU-hours for production
```

### Step 6: Production Run

```bash
# Adjust production.sh resources based on batch results
# Edit the script if needed:
nano scripts/slurm/production.sh

# Submit production run
sbatch scripts/slurm/production.sh

# Set up monitoring (in a screen/tmux session)
screen -S augmentoolkit
watch -n 30 'squeue -u $USER && tail -n 20 logs/production-*.out'
```

## Troubleshooting

### Container Not Found

**Error:** `ERROR: Container image not found`

**Solution:**
1. Verify container path: `ls -lh /projects/bbarn4-ic/containers/augmentoolkit-pipeline_latest.sif`
2. Update `CONTAINER_IMAGE` variable in the script
3. Or set environment variable: `export CONTAINER_IMAGE=/path/to/your/container.sif`

### GPU Not Detected

**Error:** Container can't access GPU

**Solution:**
1. Ensure `--nv` flag is used in `apptainer exec` command
2. Verify GPU allocation: `scontrol show job <job-id> | grep GRES`
3. Check that you're on a GPU node: `nvidia-smi`

### Manifest File Not Found

**Error:** `ERROR: Manifest file not found`

**Solution:**
1. Create manifest files (see "Creating Manifest Files" above)
2. Verify path in script matches your actual file location
3. Pass correct path as command-line argument

### Out of Memory

**Error:** Job killed due to memory limit

**Solution:**
1. Increase `#SBATCH --mem=` in the script
2. Reduce `MAX_WORKERS` to use less parallel processing
3. Reduce `concurrency_limit` in your config file

### Job Timeout

**Error:** Job reached time limit

**Solution:**
1. Increase `#SBATCH --time=` in the script
2. Use more GPUs to parallelize (increase `--gpus-per-node`)
3. Process in smaller batches

### Permission Denied

**Error:** Can't write to output directory

**Solution:**
1. Check directory permissions: `ls -ld /projects/bbarn4-ic/medicaid/data/output`
2. Create directory if needed: `mkdir -p /projects/bbarn4-ic/medicaid/data/output`
3. Ensure you have write access to the project directory

### Checkpoint/Resume Not Working

**Error:** Job doesn't resume from checkpoint

**Solution:**
1. Verify `RESUME=true` is set in production.sh
2. Check that checkpoint file exists: `ls -lh /path/to/output/checkpoints/latest.checkpoint`
3. Ensure `--resume-from-checkpoint` flag is passed to the pipeline

## Resource Guidelines

### How Many GPUs to Use?

- **Testing (1-50 PDFs):** 1 GPU is sufficient
- **Medium batch (50-200 PDFs):** 1-2 GPUs
- **Production (500+ PDFs):** 2-4 GPUs for parallelization

### Memory Requirements

- **1 GPU:** 128-256GB RAM
- **2 GPUs:** 256-512GB RAM
- **4 GPUs:** 512GB+ RAM

### Time Estimates

Based on typical Augmentoolkit processing:

- **Single PDF:** 5-15 minutes (depending on document length)
- **50 PDFs:** 4-8 hours
- **1,100 PDFs:** 2-4 days (with 2 GPUs)

**Important:** Run `batch_small.sh` first to get accurate estimates for your specific data!

## GPU-Hour Budget Management

You have 1,000 GPU-hours allocated. Calculate usage:

```
GPU-hours = (Number of GPUs) × (Job duration in hours)
```

**Example:**
- 2 GPUs for 24 hours = 48 GPU-hours
- 4 GPUs for 10 hours = 40 GPU-hours

**Recommendation:**
1. Use test jobs to estimate time per PDF
2. Calculate total GPU-hours needed for full dataset
3. Keep 10-20% buffer for retries and errors
4. Monitor usage: `sacct -u $USER --format=JobID,Elapsed,AllocGRES`

## Best Practices

1. **Always start with test_environment.sh**
   - Validates your setup before consuming GPU-hours
   - Catches configuration issues early

2. **Run test_single_pdf.sh next**
   - Verifies the full pipeline works
   - Identifies any data-specific issues

3. **Use batch_small.sh for estimates**
   - Provides realistic time/resource estimates
   - Helps optimize production script parameters

4. **Monitor production runs**
   - Use `tail -f` on log files
   - Check progress with `squeue` regularly
   - Review checkpoint files periodically

5. **Keep checkpoints enabled**
   - Enables resuming from failures
   - Don't waste GPU-hours on transient errors

6. **Save successful configurations**
   - Document working parameter combinations
   - Version control your modified scripts

## Advanced Tips

### Running Multiple Batches in Parallel

If you have many GPUs available, split your manifest:

```bash
# Split production.list into 4 chunks
split -n l/4 production.list production_part_

# Submit separate jobs
sbatch scripts/slurm/production.sh run1 production_part_aa
sbatch scripts/slurm/production.sh run2 production_part_ab
sbatch scripts/slurm/production.sh run3 production_part_ac
sbatch scripts/slurm/production.sh run4 production_part_ad
```

### Interactive Debugging

For troubleshooting, request an interactive GPU node:

```bash
srun --partition=IllinoisComputes-GPU \
     --account=bbarn4-ic \
     --gpus-per-node=1 \
     --mem=64G \
     --time=1:00:00 \
     --pty bash

# Once on the node, test commands manually
module load apptainer/latest
apptainer exec --nv /path/to/container.sif python /workspace/scripts/test_environment.py
```

### Email Notifications

Uncomment these lines in production.sh for email alerts:

```bash
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=your-netid@illinois.edu
```

## Getting Help

- **Campus Cluster Help:** help@campuscluster.illinois.edu
- **Slurm Documentation:** https://slurm.schedmd.com/
- **Campus Cluster Wiki:** https://wiki.illinois.edu/wiki/display/CCRP
- **Apptainer Documentation:** https://apptainer.org/docs/

## File Checklist

Before running production:

- [ ] Container converted to .sif format
- [ ] Container tested with `apptainer exec --nv`
- [ ] All data directories created
- [ ] Manifest files created
- [ ] Scripts made executable (`chmod +x`)
- [ ] Logs directory created
- [ ] Paths in scripts updated
- [ ] test_environment.sh completed successfully
- [ ] test_single_pdf.sh completed successfully
- [ ] batch_small.sh completed successfully
- [ ] Performance metrics reviewed
- [ ] Sufficient GPU-hours available

---

**Last Updated:** 2025-11-04

**Version:** 1.0

**Maintainer:** Your Team
