#!/bin/bash
################################################################################
# SLURM Job Script: Single PDF Test
################################################################################
#
# PURPOSE: Process exactly ONE PDF through the complete Augmentoolkit pipeline
#          to verify that the full workflow functions correctly on Campus Cluster.
#
# USAGE:
#   sbatch scripts/slurm/test_single_pdf.sh [RUN_ID] [PDF_PATH]
#
# EXAMPLES:
#   sbatch scripts/slurm/test_single_pdf.sh
#   sbatch scripts/slurm/test_single_pdf.sh test-run-01 /projects/bbarn4-ic/medicaid/data/processed/sample.pdf
#
# NOTES:
#   - This script processes a single PDF to validate the pipeline before scaling up
#   - Uses 1 GPU and allows 2 hours for processing
#   - All outputs are saved to a run-specific directory for easy review
#
################################################################################

#SBATCH --job-name=augmentoolkit-single-pdf
#SBATCH --partition=IllinoisComputes-GPU
#SBATCH --account=bbarn4-ic
#SBATCH --nodes=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --time=02:00:00
#SBATCH --output=logs/single-pdf-%j.out
#SBATCH --error=logs/single-pdf-%j.err

################################################################################
# Script Settings
################################################################################

# Exit on any error
set -euo pipefail

# CUSTOMIZE THESE PATHS FOR YOUR SETUP
CONTAINER_IMAGE="${CONTAINER_IMAGE:-/projects/bbarn4-ic/containers/augmentoolkit-pipeline_latest.sif}"
DATA_DIR="${DATA_DIR:-/projects/bbarn4-ic/medicaid/data}"
CONFIG_FILE="${CONFIG_FILE:-/workspace/configs/medicaid_config.yaml}"

# Command-line arguments (with defaults)
RUN_ID="${1:-test_single_$(date +%Y%m%d_%H%M%S)}"
PDF_PATH="${2:-/projects/bbarn4-ic/medicaid/data/processed/sample.pdf}"
OUTPUT_DIR="${3:-${DATA_DIR}/output/${RUN_ID}}"

################################################################################
# Job Information
################################################################################

echo "================================================================================"
echo "Single PDF Processing Test"
echo "================================================================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Job Name: $SLURM_JOB_NAME"
echo "Node: $(hostname)"
echo "GPUs: $SLURM_GPUS_PER_NODE"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: 128GB"
echo "Started at: $(date)"
echo "================================================================================"
echo ""
echo "Run Configuration:"
echo "  Run ID: $RUN_ID"
echo "  PDF Path: $PDF_PATH"
echo "  Output Directory: $OUTPUT_DIR"
echo "  Container: $CONTAINER_IMAGE"
echo "  Config File: $CONFIG_FILE"
echo ""

################################################################################
# Pre-Flight Checks
################################################################################

echo "Performing pre-flight checks..."

# Create necessary directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$(dirname "$OUTPUT_DIR")/logs"

# Verify container exists
if [ ! -f "$CONTAINER_IMAGE" ]; then
    echo "ERROR: Container image not found at: $CONTAINER_IMAGE"
    echo "Please update the CONTAINER_IMAGE path in this script."
    exit 1
fi

# Verify PDF exists
if [ ! -f "$PDF_PATH" ]; then
    echo "ERROR: PDF file not found at: $PDF_PATH"
    echo "Please provide a valid PDF path as the second argument."
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
# Run Augmentoolkit Pipeline
################################################################################

echo "Starting Augmentoolkit pipeline for single PDF..."
echo "--------------------------------------------------------------------------------"

# Run Augmentoolkit with the container
# --nv: Enable NVIDIA GPU support
# --bind: Mount directories from host to container
#   - Mount entire data directory for access to processed files
#   - Mount output directory for results
apptainer exec --nv \
    --bind "${DATA_DIR}:/workspace/data" \
    "$CONTAINER_IMAGE" \
    python -m augmentoolkit.processing \
        --config "$CONFIG_FILE" \
        --input "$PDF_PATH" \
        --output "$OUTPUT_DIR" \
        --run-id "$RUN_ID" \
        --max-files 1 \
        --log-level DEBUG

################################################################################
# Job Completion and Results
################################################################################

echo ""
echo "================================================================================"
echo "Single PDF processing completed!"
echo "Finished at: $(date)"
echo "================================================================================"
echo ""
echo "Output Location: $OUTPUT_DIR"
echo ""

# Check if outputs were created
if [ -d "$OUTPUT_DIR" ] && [ "$(ls -A $OUTPUT_DIR 2>/dev/null)" ]; then
    echo "Generated files:"
    ls -lh "$OUTPUT_DIR" | tail -n +2 | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
else
    echo "WARNING: Output directory is empty. Check logs for errors."
    echo ""
fi

echo "Next steps:"
echo "1. Review the output files in: $OUTPUT_DIR"
echo "2. Check the logs: logs/single-pdf-$SLURM_JOB_ID.out"
echo "3. If successful, proceed to batch_small.sh for larger-scale testing"
echo "4. If errors occurred, review: logs/single-pdf-$SLURM_JOB_ID.err"
echo ""

# Calculate processing time
if [ -n "${SECONDS:-}" ]; then
    hours=$((SECONDS / 3600))
    minutes=$(((SECONDS % 3600) / 60))
    seconds=$((SECONDS % 60))
    echo "Total processing time: ${hours}h ${minutes}m ${seconds}s"
    echo ""
fi

################################################################################
# Resource Usage Summary
################################################################################

echo "Resource Usage Summary:"
echo "--------------------------------------------------------------------------------"
sacct -j $SLURM_JOB_ID --format=JobID,JobName,Partition,AllocCPUS,State,ExitCode,Elapsed,MaxRSS,MaxVMSize | head -n 10
echo ""
