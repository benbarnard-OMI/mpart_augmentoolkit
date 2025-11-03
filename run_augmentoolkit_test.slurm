#!/bin/bash
#SBATCH --job-name=augmentoolkit-test
#SBATCH --account=REPLACE_WITH_YOUR_ACCOUNT  # REQUIRED: Replace with your ICC account name
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --output=augmentoolkit_test_%j.log
#SBATCH --error=augmentoolkit_test_%j.err

# Quick test script for Augmentoolkit - uses subset mode for faster execution
# This is useful for testing your setup before running full generation
#
# IMPORTANT: Before submitting this job:
# 1. Replace REPLACE_WITH_YOUR_ACCOUNT above with your actual ICC account
# 2. Set your API_KEY below or export it from an environment file
# 3. Ensure your input data is in ~/augmentoolkit_data/inputs/

echo "=========================================="
echo "Augmentoolkit Quick Test"
echo "Job ID: ${SLURM_JOB_ID}"
echo "=========================================="

# Validate required settings
if [[ "${SLURM_JOB_ACCOUNT}" == *"REPLACE"* ]]; then
    echo "ERROR: You must set a valid account name in the SBATCH --account directive"
    exit 1
fi

# Load required modules
module load apptainer

# Set paths
CONTAINER_PATH="${HOME}/augmentoolkit.sif"
DATA_DIR="${HOME}/augmentoolkit_data"

# Create directories
mkdir -p "${DATA_DIR}/inputs"
mkdir -p "${DATA_DIR}/outputs"
mkdir -p "${DATA_DIR}/cache"

# Test configuration - reduced parameters for quick testing
# SECURITY: Set API_KEY via environment or secure config file instead of hardcoding
# Option 1: Export before submitting: export API_KEY="your-key"; sbatch script.slurm
# Option 2: Load from secure file: source ~/secure/api_keys.sh
# Option 3: Replace the placeholder below (LEAST SECURE)
export API_KEY="${API_KEY:-REPLACE_WITH_YOUR_API_KEY}"

if [[ "${API_KEY}" == *"REPLACE"* ]]; then
    echo "ERROR: You must set a valid API_KEY"
    echo "Options:"
    echo "  1. Export before submitting: export API_KEY='your-key'; sbatch $0"
    echo "  2. Edit this script and replace REPLACE_WITH_YOUR_API_KEY"
    exit 1
fi
export INPUT_DIR=/data/inputs
export OUTPUT_DIR=/data/outputs

# Reduced parameters for testing
export VARIATION_COUNT=2                    # Minimal variations
export NUM_FACTUAL_GENERATIONS=1            # Single pass
export CONCURRENCY_LIMIT=50                 # Lower concurrency
export CHUNK_SIZE=3000                      # Smaller chunks

# Enable subset mode for faster testing
export FACTUAL_USE_SUBSET=True
export FACTUAL_SUBSET_SIZE=500              # Process only 500 items
export RAG_USE_SUBSET=True
export RAG_SUBSET_SIZE=300
export CORRECTION_USE_SUBSET=True
export CORRECTION_SUBSET_SIZE=300

# Model configuration
export FACTUAL_SMALL_MODEL="Qwen/QwQ-32B-Preview"
export FACTUAL_LARGE_MODEL="meta-llama/Meta-Llama-3.1-70B-Instruct"
export FACTUAL_SMALL_BASE_URL="https://api.deepinfra.com/v1/openai"
export FACTUAL_LARGE_BASE_URL="https://api.deepinfra.com/v1/openai"

echo "Running in TEST MODE with reduced parameters"
echo "This is a quick test - not full generation"
echo ""

# Run the container
apptainer run --nv \
  --bind "${DATA_DIR}/inputs:/data/inputs" \
  --bind "${DATA_DIR}/outputs:/data/outputs" \
  --bind "${DATA_DIR}/cache:/data/cache" \
  --env API_KEY="${API_KEY}" \
  --env INPUT_DIR="${INPUT_DIR}" \
  --env OUTPUT_DIR="${OUTPUT_DIR}" \
  --env VARIATION_COUNT="${VARIATION_COUNT}" \
  --env NUM_FACTUAL_GENERATIONS="${NUM_FACTUAL_GENERATIONS}" \
  --env CONCURRENCY_LIMIT="${CONCURRENCY_LIMIT}" \
  --env CHUNK_SIZE="${CHUNK_SIZE}" \
  --env FACTUAL_USE_SUBSET="${FACTUAL_USE_SUBSET}" \
  --env FACTUAL_SUBSET_SIZE="${FACTUAL_SUBSET_SIZE}" \
  --env RAG_USE_SUBSET="${RAG_USE_SUBSET}" \
  --env RAG_SUBSET_SIZE="${RAG_SUBSET_SIZE}" \
  --env CORRECTION_USE_SUBSET="${CORRECTION_USE_SUBSET}" \
  --env CORRECTION_SUBSET_SIZE="${CORRECTION_SUBSET_SIZE}" \
  --env FACTUAL_SMALL_MODEL="${FACTUAL_SMALL_MODEL}" \
  --env FACTUAL_LARGE_MODEL="${FACTUAL_LARGE_MODEL}" \
  --env FACTUAL_SMALL_BASE_URL="${FACTUAL_SMALL_BASE_URL}" \
  --env FACTUAL_LARGE_BASE_URL="${FACTUAL_LARGE_BASE_URL}" \
  "${CONTAINER_PATH}"

echo ""
echo "=========================================="
echo "Test completed"
echo "Check output at: ${DATA_DIR}/outputs"
echo "=========================================="
