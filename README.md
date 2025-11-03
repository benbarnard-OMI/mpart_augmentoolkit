# Augmentoolkit Docker Container for UIUC Campus Cluster

This repository contains a Docker container for running [Augmentoolkit](https://github.com/e-p-armstrong/augmentoolkit) on the UIUC Campus Cluster (ICC) with GPU acceleration. The container is designed to be content-agnostic and generate rich and numerous QA (Question-Answer) pairs from any input documents.

## Overview

Augmentoolkit is a tool for creating domain-expert datasets by generating high-quality QA pairs from source documents. This container packages Augmentoolkit with all dependencies and provides a streamlined interface for running on HPC clusters with GPU support.

### Key Features

- **Content-Agnostic**: Works with any text or PDF documents
- **Rich QA Generation**: Creates diverse, high-quality question-answer pairs
- **GPU Accelerated**: Optimized for NVIDIA GPU clusters
- **Configurable**: Extensive configuration options via environment variables
- **Campus Cluster Ready**: Designed for Apptainer/Singularity on UIUC ICC

## Quick Start

### Prerequisites

- Access to UIUC Campus Cluster
- GPU allocation on the cluster
- API key for an LLM provider (e.g., DeepInfra, OpenAI-compatible endpoint)
- Input documents (text files or PDFs)

### Building the Container

On your local machine with Docker:

```bash
# Clone this repository
git clone https://github.com/benbarnard-OMI/mpart_augmentoolkit.git
cd mpart_augmentoolkit

# Build the Docker image
docker build -t augmentoolkit:latest .

# Save the image for transfer to the cluster
docker save augmentoolkit:latest | gzip > augmentoolkit.tar.gz
```

### Converting to Apptainer/Singularity

On the UIUC Campus Cluster:

```bash
# Transfer the Docker image to the cluster
# (Use scp, rsync, or your preferred method)

# Convert Docker image to Apptainer/Singularity format
apptainer build augmentoolkit.sif docker-archive://augmentoolkit.tar.gz
```

Alternatively, build directly from Docker Hub (if image is pushed):

```bash
apptainer build augmentoolkit.sif docker://yourusername/augmentoolkit:latest
```

## Running on UIUC Campus Cluster

### Interactive Session

Request an interactive GPU session:

```bash
srun -A your_account \
     --partition=gpu \
     --gres=gpu:1 \
     --mem=32G \
     --time=04:00:00 \
     --pty bash
```

### Prepare Your Data

Create directories for your data:

```bash
mkdir -p ~/augmentoolkit_data/inputs
mkdir -p ~/augmentoolkit_data/outputs
mkdir -p ~/augmentoolkit_data/configs
mkdir -p ~/augmentoolkit_data/cache
mkdir -p ~/augmentoolkit_data/models

# Copy your input documents
cp /path/to/your/documents/* ~/augmentoolkit_data/inputs/
```

### Running the Container

Basic usage with environment variables:

```bash
apptainer run --nv \
  --bind ~/augmentoolkit_data/inputs:/data/inputs \
  --bind ~/augmentoolkit_data/outputs:/data/outputs \
  --bind ~/augmentoolkit_data/cache:/data/cache \
  --env API_KEY="your-api-key-here" \
  --env INPUT_DIR=/data/inputs \
  --env OUTPUT_DIR=/data/outputs \
  augmentoolkit.sif
```

With custom configuration:

```bash
# Create a custom configuration file
cp qa_generation.yaml ~/augmentoolkit_data/configs/my_config.yaml
# Edit the configuration as needed

apptainer run --nv \
  --bind ~/augmentoolkit_data/inputs:/data/inputs \
  --bind ~/augmentoolkit_data/outputs:/data/outputs \
  --bind ~/augmentoolkit_data/configs:/data/configs \
  --bind ~/augmentoolkit_data/cache:/data/cache \
  --env API_KEY="your-api-key-here" \
  augmentoolkit.sif --config /data/configs/my_config.yaml
```

### Batch Job Submission

Create a SLURM batch script (`run_augmentoolkit.slurm`):

```bash
#!/bin/bash
#SBATCH --job-name=augmentoolkit
#SBATCH --account=your_account
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --mem=32G
#SBATCH --time=08:00:00
#SBATCH --output=augmentoolkit_%j.log
#SBATCH --error=augmentoolkit_%j.err

# Load Apptainer module if needed
module load apptainer

# Set environment variables
export API_KEY="your-api-key-here"
export INPUT_DIR=/data/inputs
export OUTPUT_DIR=/data/outputs
export VARIATION_COUNT=6
export NUM_FACTUAL_GENERATIONS=3

# Run the container
apptainer run --nv \
  --bind ~/augmentoolkit_data/inputs:/data/inputs \
  --bind ~/augmentoolkit_data/outputs:/data/outputs \
  --bind ~/augmentoolkit_data/cache:/data/cache \
  --env API_KEY="${API_KEY}" \
  --env INPUT_DIR="${INPUT_DIR}" \
  --env OUTPUT_DIR="${OUTPUT_DIR}" \
  --env VARIATION_COUNT="${VARIATION_COUNT}" \
  --env NUM_FACTUAL_GENERATIONS="${NUM_FACTUAL_GENERATIONS}" \
  ~/augmentoolkit.sif
```

Submit the job:

```bash
sbatch run_augmentoolkit.slurm
```

## Configuration

### Environment Variables

The container supports extensive configuration via environment variables:

#### Essential Variables

- `API_KEY`: API key for your LLM provider (required)
- `INPUT_DIR`: Path to input documents (default: `/data/inputs`)
- `OUTPUT_DIR`: Path for output datasets (default: `/data/outputs`)

#### Generation Parameters

- `VARIATION_COUNT`: Number of variations per QA pair (default: `6`, higher = more diverse)
- `NUM_FACTUAL_GENERATIONS`: Number of QA generation passes (default: `3`)
- `CONCURRENCY_LIMIT`: Max concurrent API requests (default: `100`)
- `CHUNK_SIZE`: Text chunk size for processing (default: `4000`)

#### Model Configuration

- `FACTUAL_SMALL_MODEL`: Small model for factual generation (default: `Qwen/QwQ-32B-Preview`)
- `FACTUAL_LARGE_MODEL`: Large model for factual generation (default: `meta-llama/Meta-Llama-3.1-70B-Instruct`)
- `FACTUAL_SMALL_BASE_URL`: API endpoint for small model
- `FACTUAL_LARGE_BASE_URL`: API endpoint for large model

#### Processing Options

- `CITE_SOURCES`: Include source citations (default: `True`)
- `GENERIC_THOUGHT_PROCESS`: Use thought process in responses (default: `True`)
- `REMOVE_SYSTEM_PROMPT_RATIO`: Ratio of data without system prompts (default: `0.2`)
- `FACTUAL_USE_SUBSET`: Use subset of data for faster testing (default: `False`)
- `FACTUAL_SUBSET_SIZE`: Size of subset if enabled (default: `3000`)

### Custom Configuration Files

For more control, create a custom YAML configuration file based on `qa_generation.yaml`:

```yaml
pipeline: factual-datagen-pipeline

path:
  input_dirs:
    - path: /data/inputs
      variation_generation_counts: 8  # More variations
      factual_gen_subset_size_per_way: 5000
      
  output_dir: /data/outputs

system:
  number_of_factual_sft_generations_to_do: 4
  concurrency_limit: 150
  chunk_size: 5000

# ... additional configuration
```

## Output

The container generates several outputs in the `OUTPUT_DIR`:

- **QA Pairs**: JSON/JSONL files with generated question-answer pairs
- **Training Data**: Formatted data ready for model training
- **Statistics**: Generation statistics and quality metrics
- **Logs**: Detailed logs of the generation process

### Output Structure

```
outputs/
├── qa_pairs/
│   ├── qa_dataset_001.jsonl
│   ├── qa_dataset_002.jsonl
│   └── ...
├── training_data/
│   ├── pretrain.jsonl
│   ├── sft.jsonl
│   └── ...
├── stats/
│   └── generation_stats.json
└── logs/
    └── generation.log
```

## Tips for Optimal Results

### For Maximum QA Pairs

- Increase `VARIATION_COUNT` (e.g., 8-10)
- Increase `NUM_FACTUAL_GENERATIONS` (e.g., 4-5)
- Ensure sufficient GPU memory and time allocation
- Use smaller chunks if running out of memory

### For Faster Testing

- Set `FACTUAL_USE_SUBSET=True`
- Reduce `VARIATION_COUNT` to 2-3
- Reduce `NUM_FACTUAL_GENERATIONS` to 1-2
- Use `FACTUAL_SUBSET_SIZE=500` for quick tests

### For Best Quality

- Use high-quality source models (70B+ parameters)
- Enable `CITE_SOURCES=True`
- Enable `GENERIC_THOUGHT_PROCESS=True`
- Review and adjust the `shared_instruction` prompt

## Troubleshooting

### Container Won't Start

- Ensure `--nv` flag is used for GPU access
- Check that all bind mounts exist
- Verify API_KEY is set correctly

### Out of Memory Errors

- Reduce `CHUNK_SIZE` (e.g., to 2000 or 3000)
- Reduce `CONCURRENCY_LIMIT`
- Request more memory in SLURM job
- Use subset mode for testing

### No Output Generated

- Check logs in the output directory
- Verify input documents are readable
- Ensure API key has sufficient credits
- Check network connectivity to API endpoint

### Slow Generation

- Increase `CONCURRENCY_LIMIT` if API allows
- Use faster/smaller models for initial testing
- Verify GPU is being utilized (`nvidia-smi`)
- Check API rate limits

## Advanced Usage

### Using Local Models

The container can use local models instead of API endpoints. This requires:

1. More GPU memory (depending on model size)
2. Mounting a model directory with downloaded models
3. Configuring model paths in the YAML file

```bash
apptainer run --nv \
  --bind ~/models:/data/models \
  --bind ~/augmentoolkit_data/inputs:/data/inputs \
  --bind ~/augmentoolkit_data/outputs:/data/outputs \
  --env FACTUAL_SMALL_MODE=local \
  --env FACTUAL_SMALL_MODEL=/data/models/my-model \
  augmentoolkit.sif
```

### Multiple GPU Support

For multi-GPU setups:

```bash
#SBATCH --gres=gpu:4

apptainer run --nv \
  --env CUDA_VISIBLE_DEVICES=0,1,2,3 \
  # ... other options
```

### Interactive Shell

For debugging or custom workflows:

```bash
apptainer shell --nv \
  --bind ~/augmentoolkit_data:/data \
  augmentoolkit.sif
```

## Resources

- [Augmentoolkit GitHub](https://github.com/e-p-armstrong/augmentoolkit)
- [UIUC Campus Cluster Documentation](https://docs.ncsa.illinois.edu/systems/icc/)
- [Apptainer Documentation](https://apptainer.org/docs/)

## Support

For issues specific to this container, please open an issue on this repository.

For Augmentoolkit questions, refer to the [upstream project](https://github.com/e-p-armstrong/augmentoolkit) and its [Discord community](https://discord.gg/s6PBfsaVzu).

## License

This container configuration is MIT licensed. Augmentoolkit itself is also MIT licensed.
