# Quick Reference Guide

## Local Development

### Build Docker Image
```bash
docker build -t mpart-augmentoolkit:v1 .
```

### Test Environment
```bash
docker run --gpus all mpart-augmentoolkit:v1 python /workspace/scripts/test_environment.py
```

### Run Interactively
```bash
docker run --gpus all -it \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/output:/workspace/output \
  mpart-augmentoolkit:v1 bash
```

## Campus Cluster

### Submit Jobs
```bash
sbatch scripts/slurm/test_environment.sh
sbatch scripts/slurm/test_single_pdf.sh
sbatch scripts/slurm/batch_small.sh
sbatch scripts/slurm/production.sh
```

### Monitor Jobs
```bash
squeue -u $USER                    # Check job status
scontrol show job <job-id>         # Detailed job info
scancel <job-id>                   # Cancel a job
tail -f logs/slurm-<job-id>.out   # Watch logs
```

## Common Commands

### GPU Check
```bash
nvidia-smi                         # Check GPU status
```

### Docker Management
```bash
docker images                      # List images
docker ps -a                       # List containers
docker system prune                # Clean up
```

### Apptainer (on cluster)
```bash
apptainer pull docker://username/image:tag
apptainer exec --nv image.sif command
```

## File Locations

- **Config**: `configs/medicaid_config.yaml`
- **Scripts**: `scripts/slurm/`
- **Logs**: `logs/`
- **Data**: `data/processed/`
- **Output**: `output/`

## Troubleshooting

See `docs/troubleshooting.md` for detailed solutions.
