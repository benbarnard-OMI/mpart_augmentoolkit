# Quick Setup Guide

This guide will help you get started with the Augmentoolkit container on UIUC Campus Cluster in under 10 minutes.

## Step 1: Build or Obtain the Container (5 minutes)

### Option A: Build Locally and Transfer

On your local machine:

```bash
git clone https://github.com/benbarnard-OMI/mpart_augmentoolkit.git
cd mpart_augmentoolkit
./build.sh
docker save augmentoolkit:latest | gzip > augmentoolkit.tar.gz
```

Transfer to cluster:

```bash
scp augmentoolkit.tar.gz username@campus-cluster.illinois.edu:~/
```

On the cluster:

```bash
module load apptainer
apptainer build augmentoolkit.sif docker-archive://augmentoolkit.tar.gz
```

### Option B: Build on Cluster from Git (simpler)

On the cluster:

```bash
# Clone the repo
git clone https://github.com/benbarnard-OMI/mpart_augmentoolkit.git
cd mpart_augmentoolkit

# Build using Apptainer directly
module load apptainer
apptainer build augmentoolkit.sif Dockerfile
```

## Step 2: Prepare Your Data (2 minutes)

```bash
# Create data directories
mkdir -p ~/augmentoolkit_data/inputs
mkdir -p ~/augmentoolkit_data/outputs
mkdir -p ~/augmentoolkit_data/cache
mkdir -p ~/augmentoolkit_data/configs

# Add your documents
# Copy PDFs, text files, or other documents to the inputs folder
cp /path/to/your/documents/*.pdf ~/augmentoolkit_data/inputs/
# or
cp /path/to/your/documents/*.txt ~/augmentoolkit_data/inputs/
```

Example: Create a test document:

```bash
cat > ~/augmentoolkit_data/inputs/test_document.txt << 'EOF'
# Machine Learning Basics

Machine learning is a subset of artificial intelligence that enables systems to learn and improve from experience without being explicitly programmed. There are three main types of machine learning:

## Supervised Learning
In supervised learning, the algorithm learns from labeled training data. The system is presented with input-output pairs and learns to map inputs to outputs. Common applications include image classification, spam detection, and price prediction.

## Unsupervised Learning
Unsupervised learning works with unlabeled data. The algorithm tries to find hidden patterns or structures in the input data. Clustering and dimensionality reduction are typical unsupervised learning tasks.

## Reinforcement Learning
Reinforcement learning involves an agent learning to make decisions by interacting with an environment. The agent receives rewards or penalties based on its actions and learns to maximize cumulative reward over time.

## Key Algorithms
Some fundamental machine learning algorithms include:
- Linear Regression for predicting continuous values
- Decision Trees for classification and regression
- Neural Networks for complex pattern recognition
- K-Means for clustering similar data points
- Support Vector Machines for classification tasks

Machine learning has revolutionized many fields including healthcare, finance, autonomous vehicles, and natural language processing.
EOF
```

## Step 3: Configure API Access (1 minute)

Get an API key from a supported provider:

- **DeepInfra** (recommended): https://deepinfra.com/
- **OpenRouter**: https://openrouter.ai/
- **Together AI**: https://together.ai/
- Or any OpenAI-compatible endpoint

Edit the SLURM script:

```bash
cd ~/mpart_augmentoolkit
cp run_augmentoolkit_test.slurm my_test_job.slurm

# Edit the file
nano my_test_job.slurm
```

Update these lines:

```bash
#SBATCH --account=YOUR_ACCOUNT_HERE  # <-- Change this

export API_KEY="YOUR_API_KEY_HERE"   # <-- Change this
```

## Step 4: Run a Test Job (2 minutes)

Submit a test job:

```bash
cd ~/mpart_augmentoolkit
sbatch my_test_job.slurm
```

Check the status:

```bash
squeue -u $USER
```

Watch the log in real-time:

```bash
# Get the job ID from squeue output
tail -f augmentoolkit_test_JOBID.log
```

## Step 5: Check Results (1 minute)

Once the job completes:

```bash
# View generated files
ls -lh ~/augmentoolkit_data/outputs/

# View a sample of the generated QA pairs
find ~/augmentoolkit_data/outputs -name "*.json*" -type f | head -1 | xargs head -50
```

## What's Next?

### Run Full Generation

Once your test works, run the full generation:

```bash
cp run_augmentoolkit.slurm my_production_job.slurm
nano my_production_job.slurm  # Update account and API key
sbatch my_production_job.slurm
```

### Customize Configuration

For more control over the generation process:

```bash
# Copy the default config
cp qa_generation.yaml ~/augmentoolkit_data/configs/my_config.yaml

# Edit it
nano ~/augmentoolkit_data/configs/my_config.yaml

# Update your SLURM script to use it
# Add to the apptainer run command:
# --bind ~/augmentoolkit_data/configs:/data/configs \
# And change the last line to:
# augmentoolkit.sif --config /data/configs/my_config.yaml
```

### Increase QA Pair Quantity and Quality

Edit your SLURM script and increase these values:

```bash
export VARIATION_COUNT=10              # More variations per QA pair
export NUM_FACTUAL_GENERATIONS=5       # More generation passes
export CHUNK_SIZE=5000                 # Larger context chunks
```

### Process More Data

Add more documents to the input folder:

```bash
cp -r /my/document/collection/* ~/augmentoolkit_data/inputs/
```

And allocate more resources in the SLURM script:

```bash
#SBATCH --mem=64G          # More memory
#SBATCH --time=24:00:00    # More time
#SBATCH --gres=gpu:2       # More GPUs (if using local models)
```

## Troubleshooting

### Job Fails Immediately

Check the error log:

```bash
cat augmentoolkit_test_JOBID.err
```

Common issues:
- Wrong account name: Update `#SBATCH --account=`
- No GPU available: Check partition and GPU availability
- Container not found: Ensure `augmentoolkit.sif` is in the right location

### API Errors

Check your API key:
- Ensure it's valid and has credits
- Verify the base URL matches your provider
- Check rate limits

### Out of Memory

Reduce these in your SLURM script:

```bash
export CHUNK_SIZE=2000
export CONCURRENCY_LIMIT=30
```

Or request more memory:

```bash
#SBATCH --mem=64G
```

### No Input Files Found

Ensure documents are in the right location:

```bash
ls -la ~/augmentoolkit_data/inputs/
```

Must have at least one `.txt`, `.pdf`, or other document file.

## Getting Help

- Review the full [README.md](README.md)
- Check [CONTRIBUTING.md](CONTRIBUTING.md) for customization options
- Check Augmentoolkit documentation: https://github.com/e-p-armstrong/augmentoolkit
- Open an issue if you encounter problems

## Example Output

After successful generation, you'll have:

- **QA pairs**: Question-answer datasets in JSON/JSONL format
- **Training data**: Pre-formatted for model training
- **Statistics**: Quality metrics and generation stats
- **Logs**: Detailed process logs

Example QA pair:

```json
{
  "question": "What are the three main types of machine learning?",
  "answer": "The three main types of machine learning are supervised learning, unsupervised learning, and reinforcement learning. Supervised learning uses labeled data to learn input-output mappings. Unsupervised learning finds patterns in unlabeled data. Reinforcement learning involves an agent learning through interaction with an environment and receiving rewards.",
  "source": "test_document.txt",
  "difficulty": "medium"
}
```

You can use these QA pairs to:
- Train custom AI models
- Create question banks
- Build RAG systems
- Evaluate model understanding
- Generate educational content
