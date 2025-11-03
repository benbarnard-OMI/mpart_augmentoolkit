# Example Configurations

This directory contains example configuration files for different use cases.

## Available Configurations

### 1. `config_high_throughput.yaml`

**Best for:** Processing large document collections quickly

**Features:**
- Higher concurrency (200 concurrent requests)
- Larger chunk sizes (5000 tokens)
- Fewer variations (4 per QA pair)
- Fewer generation passes (2)
- Optimized for speed

**Use when:**
- You have a large corpus to process
- You need results quickly
- You're doing initial exploration
- Speed is more important than maximum quality

**Resource requirements:**
- Memory: 32GB recommended
- Time: ~4-8 hours for 100 documents
- Cost: Lower API usage

### 2. `config_high_quality.yaml`

**Best for:** Creating high-quality training datasets

**Features:**
- Lower concurrency (75 concurrent requests) for stability
- Smaller chunk sizes (3500 tokens) for precision
- Maximum variations (10 per QA pair)
- Maximum generation passes (5)
- Uses largest available models (405B)
- Processes all data (no subsets)

**Use when:**
- You're creating data for model training
- Quality is paramount
- You have time and budget
- You need diverse, accurate QA pairs

**Resource requirements:**
- Memory: 64GB recommended
- Time: ~12-24 hours for 100 documents
- Cost: Higher API usage (405B models)

## Using These Configurations

### On the Cluster

Copy the desired configuration and reference it in your SLURM script:

```bash
# Copy example to your configs directory
cp examples/config_high_quality.yaml ~/augmentoolkit_data/configs/

# In your SLURM script, add:
apptainer run --nv \
  --bind ~/augmentoolkit_data:/data \
  augmentoolkit.sif --config /data/configs/config_high_quality.yaml
```

### With Environment Variables

You can override specific settings using environment variables:

```bash
# Start with high throughput config but increase variations
apptainer run --nv \
  --bind ~/augmentoolkit_data:/data \
  --env VARIATION_COUNT=8 \
  augmentoolkit.sif --config /data/configs/config_high_throughput.yaml
```

## Creating Custom Configurations

Start with one of these examples and modify:

```bash
# Copy an example
cp examples/config_high_quality.yaml ~/augmentoolkit_data/configs/my_custom.yaml

# Edit to your needs
nano ~/augmentoolkit_data/configs/my_custom.yaml
```

### Key Parameters to Adjust

**For more QA pairs:**
- Increase `variation_generation_counts` (e.g., 8-12)
- Increase `number_of_factual_sft_generations_to_do` (e.g., 4-6)

**For faster processing:**
- Increase `chunk_size` (e.g., 5000-6000)
- Increase `concurrency_limit` (e.g., 150-250)
- Use subset modes: `factual_gen_use_subset: True`

**For better quality:**
- Decrease `chunk_size` (e.g., 2500-3500)
- Use larger models (e.g., 405B instead of 70B)
- Disable subset modes
- Lower concurrency for stability

**For cost optimization:**
- Use smaller models (e.g., 8B-32B)
- Enable subset processing
- Reduce variations and passes
- Increase chunk sizes

## Comparison Table

| Feature | High Throughput | High Quality |
|---------|----------------|--------------|
| Variations | 4 | 10 |
| Passes | 2 | 5 |
| Chunk Size | 5000 | 3500 |
| Concurrency | 200 | 75 |
| Large Model | 70B | 405B |
| Use Subsets | Some | None |
| Speed | Fast | Slow |
| Quality | Good | Excellent |
| Cost | Lower | Higher |

## Tips

1. **Start with testing**: Use subset mode first to validate your setup
2. **Monitor costs**: Watch your API usage, especially with 405B models
3. **Adjust concurrency**: If you hit rate limits, lower `concurrency_limit`
4. **Balance speed/quality**: Most use cases work well with 6 variations and 3 passes
5. **Use appropriate models**: 70B models often provide excellent quality at lower cost

## Need Help?

- Check the main [README.md](../README.md) for general documentation
- See [CONTRIBUTING.md](../CONTRIBUTING.md) for customization details
- Review the [QUICKSTART.md](../QUICKSTART.md) for step-by-step setup
