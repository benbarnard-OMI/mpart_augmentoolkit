#!/bin/bash
#SBATCH --job-name=augmentoolkit-qa
#SBATCH --account=REPLACE_WITH_YOUR_ACCOUNT  # REQUIRED: Replace with your ICC account name
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --mem=32G
#SBATCH --time=08:00:00
#SBATCH --output=augmentoolkit_%j.log
#SBATCH --error=augmentoolkit_%j.err

# Example SLURM batch script for running Augmentoolkit on UIUC Campus Cluster
# This script demonstrates basic QA generation from input documents
#
# IMPORTANT: Before submitting this job:
# 1. Replace REPLACE_WITH_YOUR_ACCOUNT above with your actual ICC account
# 2. Set your API_KEY below or export it from an environment file
# 3. Ensure your input data is in ~/augmentoolkit_data/inputs/

echo "=========================================="
echo "Augmentoolkit QA Generation Job"
echo "Job ID: ${SLURM_JOB_ID}"
echo "Running on: $(hostname)"
echo "Started at: $(date)"
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

# Verify container exists
if [ ! -f "${CONTAINER_PATH}" ]; then
    echo "Error: Container not found at ${CONTAINER_PATH}"
    exit 1
fi

# Create data directories if they don't exist
mkdir -p "${DATA_DIR}/inputs"
mkdir -p "${DATA_DIR}/outputs"
mkdir -p "${DATA_DIR}/cache"
mkdir -p "${DATA_DIR}/configs"

# Set environment variables for configuration
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

# Generation parameters - adjust as needed
export VARIATION_COUNT=6                    # Number of QA variations (higher = more diverse)
export NUM_FACTUAL_GENERATIONS=3            # Number of generation passes
export CONCURRENCY_LIMIT=100                # Max concurrent API requests
export CHUNK_SIZE=4000                      # Text chunk size
export CITE_SOURCES=True                    # Include source citations
export GENERIC_THOUGHT_PROCESS=True         # Use thought process structure

# Model configuration (using DeepInfra as example)
export FACTUAL_SMALL_MODEL="Qwen/QwQ-32B-Preview"
export FACTUAL_LARGE_MODEL="meta-llama/Meta-Llama-3.1-70B-Instruct"
export FACTUAL_SMALL_BASE_URL="https://api.deepinfra.com/v1/openai"
export FACTUAL_LARGE_BASE_URL="https://api.deepinfra.com/v1/openai"

echo "Configuration:"
echo "  Input Directory: ${DATA_DIR}/inputs"
echo "  Output Directory: ${DATA_DIR}/outputs"
echo "  Variation Count: ${VARIATION_COUNT}"
echo "  Generation Passes: ${NUM_FACTUAL_GENERATIONS}"
echo "  Chunk Size: ${CHUNK_SIZE}"
echo ""

# Check for input files
INPUT_COUNT=$(find "${DATA_DIR}/inputs" -type f | wc -l)
if [ ${INPUT_COUNT} -eq 0 ]; then
    echo "Warning: No input files found in ${DATA_DIR}/inputs"
    echo "Please add documents to process before running this job."
    exit 1
fi
echo "Found ${INPUT_COUNT} input file(s)"

# Print GPU information
echo ""
echo "GPU Information:"
nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader
echo ""

# Run the container
echo "Starting Augmentoolkit container..."
apptainer run --nv \
  --bind "${DATA_DIR}/inputs:/data/inputs" \
  --bind "${DATA_DIR}/outputs:/data/outputs" \
  --bind "${DATA_DIR}/cache:/data/cache" \
  --bind "${DATA_DIR}/configs:/data/configs" \
  --env API_KEY="${API_KEY}" \
  --env INPUT_DIR="${INPUT_DIR}" \
  --env OUTPUT_DIR="${OUTPUT_DIR}" \
  --env VARIATION_COUNT="${VARIATION_COUNT}" \
  --env NUM_FACTUAL_GENERATIONS="${NUM_FACTUAL_GENERATIONS}" \
  --env CONCURRENCY_LIMIT="${CONCURRENCY_LIMIT}" \
  --env CHUNK_SIZE="${CHUNK_SIZE}" \
  --env CITE_SOURCES="${CITE_SOURCES}" \
  --env GENERIC_THOUGHT_PROCESS="${GENERIC_THOUGHT_PROCESS}" \
  --env FACTUAL_SMALL_MODEL="${FACTUAL_SMALL_MODEL}" \
  --env FACTUAL_LARGE_MODEL="${FACTUAL_LARGE_MODEL}" \
  --env FACTUAL_SMALL_BASE_URL="${FACTUAL_SMALL_BASE_URL}" \
  --env FACTUAL_LARGE_BASE_URL="${FACTUAL_LARGE_BASE_URL}" \
  "${CONTAINER_PATH}"

EXIT_CODE=$?

echo ""
echo "=========================================="
echo "Job completed with exit code: ${EXIT_CODE}"
echo "Finished at: $(date)"

# Show output summary if successful
if [ ${EXIT_CODE} -eq 0 ]; then
    echo ""
    echo "Output files generated:"
    find "${DATA_DIR}/outputs" -type f -name "*.json*" -o -name "*.txt" | head -20
    echo ""
    echo "Check ${DATA_DIR}/outputs for generated QA pairs"
fi

echo "=========================================="

exit ${EXIT_CODE}
