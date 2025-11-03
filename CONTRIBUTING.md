# Contributing to Augmentoolkit Container

This guide explains how to customize and extend the Augmentoolkit container for your specific needs.

## Customizing the Configuration

### Using Environment Variables

The easiest way to customize the container is through environment variables. See the main README for a complete list.

Example custom script:

```bash
export VARIATION_COUNT=10
export NUM_FACTUAL_GENERATIONS=5
export CHUNK_SIZE=5000
export FACTUAL_SMALL_MODEL="custom-model-name"

apptainer run --nv \
  --bind ~/data:/data \
  --env VARIATION_COUNT="${VARIATION_COUNT}" \
  --env NUM_FACTUAL_GENERATIONS="${NUM_FACTUAL_GENERATIONS}" \
  # ... other variables
  augmentoolkit.sif
```

### Custom Configuration Files

For more complex customization, create a YAML configuration file:

1. Copy `qa_generation.yaml` as a template
2. Modify the parameters as needed
3. Mount it into the container:

```bash
apptainer run --nv \
  --bind ~/my_config.yaml:/data/configs/my_config.yaml \
  --bind ~/data:/data \
  augmentoolkit.sif --config /data/configs/my_config.yaml
```

## Customizing the Dockerfile

### Adding System Dependencies

To add additional system packages:

```dockerfile
# In Dockerfile, add to the RUN apt-get install section:
RUN apt-get update && apt-get install -y \
    # ... existing packages ...
    your-package-here \
    another-package \
    && rm -rf /var/lib/apt/lists/*
```

### Adding Python Packages

To add Python dependencies:

```dockerfile
# After the requirements.txt installation:
RUN pip install --no-cache-dir \
    your-package-name \
    another-package
```

Or create a `requirements-custom.txt` file and add:

```dockerfile
COPY requirements-custom.txt .
RUN pip install --no-cache-dir -r requirements-custom.txt
```

### Using a Specific Augmentoolkit Version

To use a specific version of Augmentoolkit:

```dockerfile
# Replace the git clone line with:
RUN git clone https://github.com/e-p-armstrong/augmentoolkit.git . && \
    git checkout <specific-tag-or-commit>
```

## Extending the Entrypoint Script

The `entrypoint.sh` script controls how the container runs. Common customizations:

### Adding Pre-processing

Add custom processing before Augmentoolkit runs:

```bash
# In entrypoint.sh, before running Augmentoolkit:
echo "Running custom pre-processing..."
python /custom_scripts/preprocess.py
```

### Adding Post-processing

Add custom processing after Augmentoolkit completes:

```bash
# At the end of entrypoint.sh:
echo "Running custom post-processing..."
python /custom_scripts/postprocess.py
```

### Custom Environment Setup

Add custom environment configuration:

```bash
# Near the top of entrypoint.sh:
# Load custom environment variables
if [ -f "/data/configs/env.sh" ]; then
    source /data/configs/env.sh
fi
```

## Custom Pipeline Configurations

### Creating a Custom Pipeline

1. Create a new YAML configuration based on `qa_generation.yaml`
2. Modify the pipeline order:

```yaml
pipeline_order:
  - node: pdf-clean-convert-pipeline  # Add PDF cleaning
    config: external:/data/configs/pdf_config.yaml
  - node: factual-datagen-pipeline    # Then generate QA
    config: external:/data/configs/qa_config.yaml
```

3. Configure each pipeline's parameters

### Chaining Multiple Pipelines

To run multiple pipelines in sequence:

```yaml
pipeline_order:
  - node: factual-datagen-pipeline
    config: external:/data/configs/qa_gen1.yaml
  - node: representation-variation-pipeline
    config: external:/data/configs/repvar.yaml
  - node: correction-pipeline
    config: external:/data/configs/correction.yaml
```

## Building Custom Variants

### For Different LLM Providers

Create provider-specific configurations:

**DeepInfra variant** (`config_deepinfra.yaml`):
```yaml
factual:
  factual_small_base_url: https://api.deepinfra.com/v1/openai
  factual_large_base_url: https://api.deepinfra.com/v1/openai
  factual_small_model: Qwen/QwQ-32B-Preview
  factual_large_model: meta-llama/Meta-Llama-3.1-70B-Instruct
```

**OpenRouter variant** (`config_openrouter.yaml`):
```yaml
factual:
  factual_small_base_url: https://openrouter.ai/api/v1
  factual_large_base_url: https://openrouter.ai/api/v1
  factual_small_model: qwen/qwq-32b-preview
  factual_large_model: meta-llama/llama-3.1-70b-instruct
```

### For Different Data Types

**PDF-heavy workloads**:
```yaml
pdf_cleaning:
  pdf_cleaning_chunk_size: 3000  # Smaller chunks for PDFs
  
path:
  input_dirs:
    - path: /data/inputs
      variation_generation_counts: 4
```

**Large text corpora**:
```yaml
system:
  chunk_size: 6000  # Larger chunks
  concurrency_limit: 200  # Higher concurrency
```

## Testing Your Customizations

### Local Testing

Test with a small dataset first:

```bash
# Create test data
mkdir -p test_data/inputs test_data/outputs
echo "Sample text for testing" > test_data/inputs/test.txt

# Test locally (requires Docker + GPU)
docker run --gpus all \
  -v $(pwd)/test_data:/data \
  -e API_KEY="your-key" \
  -e FACTUAL_USE_SUBSET=True \
  -e FACTUAL_SUBSET_SIZE=10 \
  augmentoolkit:latest
```

### Cluster Testing

Use the test SLURM script:

```bash
# Edit run_augmentoolkit_test.slurm with your account
# Submit test job
sbatch run_augmentoolkit_test.slurm

# Monitor
squeue -u $USER
tail -f augmentoolkit_test_*.log
```

## Common Customization Scenarios

### High-throughput Processing

For processing large amounts of data quickly:

```yaml
system:
  concurrency_limit: 300
  chunk_size: 5000
  
path:
  input_dirs:
    - path: /data/inputs
      variation_generation_counts: 4  # Fewer variations
      factual_gen_use_subset: False
      
factual:
  factual_small_model: faster-smaller-model
```

### High-quality Output

For maximum quality over speed:

```yaml
system:
  concurrency_limit: 50  # Lower for stability
  
path:
  input_dirs:
    - path: /data/inputs
      variation_generation_counts: 10  # More variations
      
factual:
  factual_small_model: Qwen/QwQ-32B-Preview
  factual_large_model: meta-llama/Meta-Llama-3.1-405B-Instruct  # Largest model
```

### Cost-optimized Processing

To minimize API costs:

```yaml
system:
  concurrency_limit: 30
  
path:
  input_dirs:
    - path: /data/inputs
      variation_generation_counts: 3
      factual_gen_subset_size_per_way: 1000
      factual_gen_use_subset: True
      
factual:
  factual_small_model: smaller-cheaper-model
  factual_large_model: medium-cost-model
```

## Troubleshooting Custom Configurations

### Validation

Always validate your YAML files:

```bash
python -c "import yaml; yaml.safe_load(open('my_config.yaml'))"
```

### Debugging

Enable verbose output:

```bash
# Add to entrypoint.sh or pass as environment variable
export AUGMENTOOLKIT_DEBUG=1
export PYTHONVERBOSE=1
```

### Common Issues

1. **YAML syntax errors**: Use a YAML validator
2. **Path not found**: Ensure all paths are absolute or relative to `/augmentoolkit`
3. **Environment variables not expanding**: Check the syntax in YAML (`${VAR:-default}`)
4. **API errors**: Verify API keys and endpoints are correct

## Sharing Your Customizations

If you create useful customizations, consider:

1. Creating a pull request to add example configurations
2. Sharing in the discussions/issues
3. Documenting your use case in a separate file

## Getting Help

- Check the [Augmentoolkit documentation](https://github.com/e-p-armstrong/augmentoolkit)
- Review the configuration examples in `qa_generation.yaml`
- Open an issue for container-specific problems
- Join the [Augmentoolkit Discord](https://discord.gg/s6PBfsaVzu) for general questions
