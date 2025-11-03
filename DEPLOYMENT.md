# Deployment Guide for UIUC Campus Cluster

This guide provides detailed deployment instructions for the Augmentoolkit container on the UIUC Campus Cluster (ICC).

## Prerequisites

Before deploying, ensure you have:

1. **Cluster Access**
   - Active UIUC ICC account
   - Access to GPU partition
   - Sufficient allocation balance

2. **API Access**
   - API key from a supported LLM provider
   - Sufficient credits for your workload
   - Verified API endpoint accessibility

3. **Input Data**
   - Documents prepared for processing
   - Documents in supported formats (TXT, PDF, DOCX)
   - Documents accessible on cluster storage

## Deployment Steps

### 1. Initial Setup on Cluster

SSH into the cluster:

```bash
ssh your_netid@campus-cluster.illinois.edu
```

Create directory structure:

```bash
# Create base directory
mkdir -p ~/augmentoolkit
cd ~/augmentoolkit

# Create data directories
mkdir -p data/inputs data/outputs data/configs data/cache data/models

# Clone this repository
git clone https://github.com/benbarnard-OMI/mpart_augmentoolkit.git
cd mpart_augmentoolkit
```

### 2. Build the Container

#### Option A: Build from Dockerfile (Recommended)

```bash
# Load Apptainer
module load apptainer

# Build the container
apptainer build augmentoolkit.sif Dockerfile

# This will take 10-20 minutes
# The resulting file will be ~5-8GB
```

#### Option B: Build from Docker Archive

If you built on a local machine:

```bash
# Transfer the archive to cluster
scp augmentoolkit.tar.gz your_netid@campus-cluster.illinois.edu:~/augmentoolkit/

# On the cluster
module load apptainer
apptainer build augmentoolkit.sif docker-archive://augmentoolkit.tar.gz
```

Verify the build:

```bash
# Check the container
apptainer inspect augmentoolkit.sif

# Test basic functionality
apptainer exec augmentoolkit.sif python --version
```

### 3. Prepare Your Data

Transfer your documents to the cluster:

```bash
# From your local machine
scp -r /path/to/your/documents your_netid@campus-cluster.illinois.edu:~/augmentoolkit/data/inputs/
```

Or if data is on cluster:

```bash
# Copy from project storage
cp -r /projects/your_project/documents/* ~/augmentoolkit/data/inputs/
```

Verify your data:

```bash
# Check file count
find ~/augmentoolkit/data/inputs -type f | wc -l

# Check total size
du -sh ~/augmentoolkit/data/inputs
```

### 4. Configure Your Job

Create a configuration file:

```bash
# Copy example configuration
cp examples/config_high_throughput.yaml ~/augmentoolkit/data/configs/my_job.yaml

# Edit as needed
nano ~/augmentoolkit/data/configs/my_job.yaml
```

Or use environment variables (simpler for testing):

```bash
# Create environment file
cat > ~/augmentoolkit/env_config.sh << 'EOF'
export API_KEY="your-api-key-here"
export INPUT_DIR=/data/inputs
export OUTPUT_DIR=/data/outputs
export VARIATION_COUNT=6
export NUM_FACTUAL_GENERATIONS=3
export CONCURRENCY_LIMIT=100
EOF
```

### 5. Create SLURM Job Script

```bash
# Copy template
cp run_augmentoolkit.slurm ~/augmentoolkit/my_job.slurm

# Edit with your details
nano ~/augmentoolkit/my_job.slurm
```

Key parameters to update:

```bash
#SBATCH --account=your_account_name     # YOUR ACCOUNT
#SBATCH --time=08:00:00                 # Adjust based on workload
#SBATCH --mem=32G                       # Adjust based on data size

export API_KEY="your-api-key"           # YOUR API KEY
```

### 6. Submit and Monitor

Submit your job:

```bash
sbatch my_job.slurm
```

Monitor the job:

```bash
# Check job status
squeue -u $USER

# Watch log in real-time
tail -f augmentoolkit_*.log

# Check specific job
scontrol show job JOBID
```

### 7. Retrieve Results

Once complete, check your outputs:

```bash
# List output files
ls -lh ~/augmentoolkit/data/outputs/

# Check output size
du -sh ~/augmentoolkit/data/outputs/

# Transfer to local machine (from local)
scp -r your_netid@campus-cluster.illinois.edu:~/augmentoolkit/data/outputs/ ./
```

## Resource Allocation Guidelines

### Memory Requirements

| Input Size | Recommended Memory |
|------------|-------------------|
| < 100 MB   | 16 GB             |
| 100-500 MB | 32 GB             |
| 500 MB-2GB | 64 GB             |
| > 2 GB     | 128 GB            |

### Time Estimates

Based on ~100 documents with default settings:

| Configuration | Estimated Time |
|---------------|---------------|
| Test mode (subset) | 1-2 hours |
| High throughput | 4-8 hours |
| Balanced | 8-12 hours |
| High quality | 12-24 hours |

**Note:** Times vary based on:
- Number of documents
- Document size and complexity
- API speed and availability
- Concurrency settings
- Model size and speed

### GPU Requirements

- **Minimum**: 1 GPU (for API-based generation)
- **Recommended**: 1 GPU with 16GB+ VRAM
- **For local models**: 2-4 GPUs with 40GB+ VRAM each

## Best Practices

### 1. Start Small

Always test with a small subset first:

```bash
# Submit test job
sbatch run_augmentoolkit_test.slurm

# Verify output quality
# Then scale up
```

### 2. Monitor Costs

Track API usage:

```bash
# Check logs for API call counts
grep -i "api" augmentoolkit_*.log | wc -l

# Estimate costs before full run
# For DeepInfra: ~$0.20-0.40 per 1M tokens
```

### 3. Use Batch Processing

For very large datasets:

```bash
# Split into batches
split -n 5 file_list.txt batch_

# Process each batch separately
for batch in batch_*; do
    # Create separate job for each
    sbatch --export=BATCH_FILE=$batch my_job.slurm
done
```

### 4. Optimize Storage

```bash
# Clean up cache periodically
rm -rf ~/augmentoolkit/data/cache/*

# Compress outputs before transfer
tar -czf outputs.tar.gz ~/augmentoolkit/data/outputs/
```

### 5. Handle Long Jobs

For jobs > 24 hours:

```bash
# Use checkpointing
export CHECKPOINT_INTERVAL=3600  # Every hour

# Or split into multiple jobs
# Process different input directories separately
```

## Troubleshooting

### Container Build Failures

```bash
# If build fails with network errors
module load apptainer
export APPTAINER_CACHEDIR=~/apptainer_cache
mkdir -p $APPTAINER_CACHEDIR
apptainer build --fix-perms augmentoolkit.sif Dockerfile

# If out of space
# Check quota
quota -s
# Clean cache
rm -rf ~/.apptainer/cache/*
```

### Job Failures

```bash
# Check error log
cat augmentoolkit_*.err

# Check job details
scontrol show job JOBID

# Common issues:
# 1. Out of memory -> Increase --mem
# 2. Timeout -> Increase --time
# 3. GPU not available -> Check partition
```

### API Issues

```bash
# Test API connectivity from compute node
srun --partition=gpu --gres=gpu:1 --pty bash
curl -H "Authorization: Bearer $API_KEY" https://api.deepinfra.com/v1/models

# If blocked, contact cluster support
```

### Permission Errors

```bash
# Fix permissions
chmod -R u+rwX ~/augmentoolkit/data/

# Ensure scripts are executable
chmod +x ~/augmentoolkit/mpart_augmentoolkit/*.sh
```

## Advanced Configuration

### Using Local Models

If you have local model files:

```bash
# Mount model directory
apptainer run --nv \
  --bind ~/models:/data/models \
  --env FACTUAL_SMALL_MODE=local \
  --env FACTUAL_SMALL_MODEL=/data/models/qwen-32b \
  augmentoolkit.sif
```

### Multi-GPU Jobs

```bash
#SBATCH --gres=gpu:4

apptainer run --nv \
  --env CUDA_VISIBLE_DEVICES=0,1,2,3 \
  # Configure vLLM tensor parallelism
  augmentoolkit.sif
```

### Custom Pipelines

```bash
# Run specific pipeline
apptainer run augmentoolkit.sif \
  --node factual-gen-indiv-pipeline \
  --config /data/configs/custom_pipeline.yaml
```

## Maintenance

### Regular Updates

```bash
# Update container
cd ~/augmentoolkit/mpart_augmentoolkit
git pull
apptainer build --force augmentoolkit.sif Dockerfile
```

### Cleanup

```bash
# Remove old outputs
find ~/augmentoolkit/data/outputs -mtime +30 -delete

# Clean cache
rm -rf ~/augmentoolkit/data/cache/*

# Archive old jobs
tar -czf old_outputs_$(date +%Y%m%d).tar.gz ~/augmentoolkit/data/outputs/
```

## Support

### Cluster-Specific Issues

- ICC Help: help@campuscluster.illinois.edu
- Documentation: https://docs.ncsa.illinois.edu/systems/icc/

### Container Issues

- Open issue: https://github.com/benbarnard-OMI/mpart_augmentoolkit/issues
- Check documentation in this repository

### Augmentoolkit Questions

- Upstream docs: https://github.com/e-p-armstrong/augmentoolkit
- Discord: https://discord.gg/s6PBfsaVzu

## Checklist for Production Deployment

- [ ] Container built and tested
- [ ] Input data transferred and verified
- [ ] API key configured and tested
- [ ] SLURM script customized
- [ ] Test job completed successfully
- [ ] Resource allocation appropriate
- [ ] Monitoring plan in place
- [ ] Output destination configured
- [ ] Backup strategy defined
- [ ] Documentation reviewed

## Next Steps

After successful deployment:

1. **Monitor first production run** - Watch logs and resource usage
2. **Validate outputs** - Check quality of generated QA pairs
3. **Optimize settings** - Adjust based on results and resource usage
4. **Scale up** - Process larger datasets or increase quality settings
5. **Automate** - Create workflows for regular processing

For detailed usage instructions, see [README.md](README.md) and [QUICKSTART.md](QUICKSTART.md).
