#!/bin/bash
################################################################################
# SLURM Job Script: Small Batch Processing (50 PDFs)
################################################################################
#
# PURPOSE: Process a batch of 50 PDFs through the Augmentoolkit pipeline to
#          validate scalability and estimate resource requirements before
#          running the full production workload.
#
# USAGE:
#   sbatch scripts/slurm/batch_small.sh [RUN_ID] [MANIFEST_FILE]
#
# EXAMPLES:
#   sbatch scripts/slurm/batch_small.sh
#   sbatch scripts/slurm/batch_small.sh batch-50-test /projects/bbarn4-ic/medicaid/data/processed/manifests/batch_50.list
#
# NOTES:
#   - Processes up to 50 PDFs to test pipeline at scale
#   - Uses 1 GPU with 8 hours of processing time
#   - Manifest file should contain one PDF path per line
#   - Good for estimating time/resources before full production run
#
################################################################################

#SBATCH --job-name=augmentoolkit-batch-50
#SBATCH --partition=IllinoisComputes-GPU
#SBATCH --account=bbarn4-ic
#SBATCH --nodes=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=256G
#SBATCH --time=08:00:00
#SBATCH --output=logs/batch-50-%j.out
#SBATCH --error=logs/batch-50-%j.err

################################################################################
# Script Settings
################################################################################

# Exit on any error, treat unset variables as errors
set -euo pipefail

# CUSTOMIZE THESE PATHS FOR YOUR SETUP
CONTAINER_IMAGE="${CONTAINER_IMAGE:-/projects/bbarn4-ic/containers/augmentoolkit-pipeline_latest.sif}"
DATA_DIR="${DATA_DIR:-/projects/bbarn4-ic/medicaid/data}"
CONFIG_FILE="${CONFIG_FILE:-/workspace/configs/medicaid_config.yaml}"

# Command-line arguments (with defaults)
RUN_ID="${1:-batch_50_$(date +%Y%m%d_%H%M%S)}"
MANIFEST="${2:-/projects/bbarn4-ic/medicaid/data/processed/manifests/batch_50.list}"
OUTPUT_DIR="${3:-${DATA_DIR}/output/${RUN_ID}}"

# Processing parameters
MAX_WORKERS="${MAX_WORKERS:-4}"  # Parallel workers for processing
BATCH_SIZE="${BATCH_SIZE:-50}"   # Maximum number of PDFs to process

################################################################################
# Job Information
################################################################################

echo "================================================================================"
echo "Small Batch Processing (50 PDFs)"
echo "================================================================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Job Name: $SLURM_JOB_NAME"
echo "Node: $(hostname)"
echo "GPUs: $SLURM_GPUS_PER_NODE"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: 256GB"
echo "Time Limit: 8 hours"
echo "Started at: $(date)"
echo "================================================================================"
echo ""
echo "Run Configuration:"
echo "  Run ID: $RUN_ID"
echo "  Manifest File: $MANIFEST"
echo "  Output Directory: $OUTPUT_DIR"
echo "  Container: $CONTAINER_IMAGE"
echo "  Config File: $CONFIG_FILE"
echo "  Max Workers: $MAX_WORKERS"
echo "  Batch Size: $BATCH_SIZE"
echo ""

################################################################################
# Pre-Flight Checks
################################################################################

echo "Performing pre-flight checks..."

# Create necessary directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "${OUTPUT_DIR}/logs"
mkdir -p "$(dirname "$OUTPUT_DIR")/checkpoints"

# Verify container exists
if [ ! -f "$CONTAINER_IMAGE" ]; then
    echo "ERROR: Container image not found at: $CONTAINER_IMAGE"
    echo "Please update the CONTAINER_IMAGE path in this script."
    exit 1
fi

# Verify manifest exists
if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: Manifest file not found at: $MANIFEST"
    echo ""
    echo "The manifest file should contain one PDF path per line, for example:"
    echo "  /projects/bbarn4-ic/medicaid/data/processed/doc1.pdf"
    echo "  /projects/bbarn4-ic/medicaid/data/processed/doc2.pdf"
    echo "  ..."
    echo ""
    echo "Please create the manifest file or provide a valid path."
    exit 1
fi

# Count PDFs in manifest
PDF_COUNT=$(wc -l < "$MANIFEST")
echo "✓ Found $PDF_COUNT PDFs in manifest"

if [ "$PDF_COUNT" -gt "$BATCH_SIZE" ]; then
    echo "  WARNING: Manifest contains $PDF_COUNT PDFs, but batch size is $BATCH_SIZE"
    echo "  Only the first $BATCH_SIZE PDFs will be processed"
fi

if [ "$PDF_COUNT" -eq 0 ]; then
    echo "ERROR: Manifest file is empty"
    exit 1
fi

echo "✓ All pre-flight checks passed"
echo ""

################################################################################
# Load Required Modules
################################################################################

echo "Loading modules..."
module purge
module load apptainer/latest

echo "Apptainer version: $(apptainer --version)"
echo ""

################################################################################
# GPU Information
################################################################################

echo "GPU Information:"
echo "--------------------------------------------------------------------------------"
nvidia-smi --query-gpu=index,name,memory.total,memory.free --format=csv,noheader,nounits
echo ""

################################################################################
# Display Sample of PDFs to Process
################################################################################

echo "Sample of PDFs to process (first 10):"
echo "--------------------------------------------------------------------------------"
head -n 10 "$MANIFEST" | nl -w 3 -s '. '
if [ "$PDF_COUNT" -gt 10 ]; then
    echo "  ... and $((PDF_COUNT - 10)) more"
fi
echo ""

################################################################################
# Run Augmentoolkit Pipeline
################################################################################

echo "Starting Augmentoolkit batch processing..."
echo "--------------------------------------------------------------------------------"
echo "Processing will begin at: $(date)"
echo ""

# Track start time
START_TIME=$SECONDS

# Run Augmentoolkit with the container
# --nv: Enable NVIDIA GPU support
# --bind: Mount directories from host to container
apptainer exec --nv \
    --bind "${DATA_DIR}:/workspace/data" \
    "$CONTAINER_IMAGE" \
    python -m augmentoolkit.processing \
        --config "$CONFIG_FILE" \
        --manifest "$MANIFEST" \
        --output "$OUTPUT_DIR" \
        --run-id "$RUN_ID" \
        --max-files "$BATCH_SIZE" \
        --max-workers "$MAX_WORKERS" \
        --checkpoint-interval 10 \
        --log-level INFO

# Calculate processing time
ELAPSED=$((SECONDS - START_TIME))

################################################################################
# Job Completion and Results
################################################################################

echo ""
echo "================================================================================"
echo "Batch processing completed!"
echo "Finished at: $(date)"
echo "================================================================================"
echo ""

# Format elapsed time
hours=$((ELAPSED / 3600))
minutes=$(((ELAPSED % 3600) / 60))
seconds=$((ELAPSED % 60))
echo "Total processing time: ${hours}h ${minutes}m ${seconds}s"

# Calculate average time per PDF
if [ "$PDF_COUNT" -gt 0 ]; then
    avg_seconds=$((ELAPSED / PDF_COUNT))
    avg_minutes=$((avg_seconds / 60))
    echo "Average time per PDF: ${avg_minutes}m $((avg_seconds % 60))s"
fi
echo ""

echo "Output Location: $OUTPUT_DIR"
echo ""

# Check if outputs were created
if [ -d "$OUTPUT_DIR" ] && [ "$(ls -A $OUTPUT_DIR 2>/dev/null)" ]; then
    echo "Output summary:"
    
    # Count generated files by type
    json_count=$(find "$OUTPUT_DIR" -name "*.json" -type f 2>/dev/null | wc -l)
    jsonl_count=$(find "$OUTPUT_DIR" -name "*.jsonl" -type f 2>/dev/null | wc -l)
    
    echo "  JSON files: $json_count"
    echo "  JSONL files: $jsonl_count"
    echo ""
    
    # Show directory size
    output_size=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
    echo "  Total output size: $output_size"
    echo ""
else
    echo "WARNING: Output directory is empty or missing. Check logs for errors."
    echo ""
fi

################################################################################
# Performance Metrics and Recommendations
################################################################################

echo "Performance Analysis:"
echo "--------------------------------------------------------------------------------"

# Estimate full production time based on this batch
if [ "$PDF_COUNT" -gt 0 ] && [ "$ELAPSED" -gt 0 ]; then
    TOTAL_PDFS=1100  # Total PDFs for production run
    
    # Estimate time for full production (in hours)
    est_seconds=$((ELAPSED * TOTAL_PDFS / PDF_COUNT))
    est_hours=$((est_seconds / 3600))
    est_days=$((est_hours / 24))
    est_hours_remaining=$((est_hours % 24))
    
    echo "Estimated time for $TOTAL_PDFS PDFs: ${est_days}d ${est_hours_remaining}h"
    echo ""
    
    # GPU-hours calculation
    gpu_hours=$((est_hours * 1))  # Assuming 1 GPU
    echo "Estimated GPU-hours needed: $gpu_hours (you have 1,000 available)"
    echo ""
    
    if [ "$gpu_hours" -gt 1000 ]; then
        echo "WARNING: Estimated GPU-hours exceeds your allocation!"
        echo "Consider:"
        echo "  - Using 2+ GPUs in production.sh to parallelize"
        echo "  - Optimizing concurrency settings in the config"
        echo "  - Processing in multiple batches"
    else
        echo "✓ Estimated usage is within your GPU-hour allocation"
    fi
fi

echo ""
echo "Next steps:"
echo "1. Review the output files in: $OUTPUT_DIR"
echo "2. Check processing logs: logs/batch-50-$SLURM_JOB_ID.out"
echo "3. Verify QA quality in the generated JSONL files"
echo "4. If satisfied with results, proceed to production.sh"
echo "5. Adjust production.sh resources based on the performance metrics above"
echo ""

################################################################################
# Resource Usage Summary
################################################################################

echo "Resource Usage Summary:"
echo "--------------------------------------------------------------------------------"
sacct -j $SLURM_JOB_ID --format=JobID,JobName,Partition,AllocCPUS,State,ExitCode,Elapsed,MaxRSS,MaxVMSize 2>/dev/null | head -n 10 || echo "sacct not available"
echo ""
