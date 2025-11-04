#!/bin/bash
################################################################################
# SLURM Job Script: Production Run (Up to 1,100 PDFs)
################################################################################
#
# PURPOSE: Process the full dataset of Medicaid policy PDFs through the
#          Augmentoolkit pipeline for production-grade QA dataset generation.
#
# USAGE:
#   sbatch scripts/slurm/production.sh [RUN_ID] [MANIFEST_FILE]
#
# EXAMPLES:
#   sbatch scripts/slurm/production.sh
#   sbatch scripts/slurm/production.sh prod-2025-11-04 /projects/bbarn4-ic/medicaid/data/processed/manifests/production.list
#
# NOTES:
#   - Designed for large-scale processing (up to 1,100 PDFs)
#   - Uses 2 GPUs for parallel processing (adjust --gpus-per-node as needed)
#   - Includes robust error handling and resume capabilities
#   - Checkpoint every 25 files to enable recovery from failures
#   - Monitor progress with: squeue -u $USER and tail -f logs/production-*.out
#
# BEFORE RUNNING:
#   1. Complete test_environment.sh successfully
#   2. Complete test_single_pdf.sh successfully
#   3. Complete batch_small.sh and review performance metrics
#   4. Adjust resource allocations below based on batch_small.sh results
#   5. Ensure you have sufficient GPU-hours remaining
#
################################################################################

#SBATCH --job-name=augmentoolkit-production
#SBATCH --partition=IllinoisComputes-GPU
#SBATCH --account=bbarn4-ic
#SBATCH --nodes=1
#SBATCH --gpus-per-node=2
#SBATCH --cpus-per-task=32
#SBATCH --mem=512G
#SBATCH --time=48:00:00
#SBATCH --output=logs/production-%j.out
#SBATCH --error=logs/production-%j.err

# Email notifications (optional - uncomment and add your email)
##SBATCH --mail-type=BEGIN,END,FAIL
##SBATCH --mail-user=your-email@illinois.edu

################################################################################
# Script Settings
################################################################################

# Exit on error, but allow for graceful recovery
set -uo pipefail

# CUSTOMIZE THESE PATHS FOR YOUR SETUP
CONTAINER_IMAGE="${CONTAINER_IMAGE:-/projects/bbarn4-ic/containers/augmentoolkit-pipeline_latest.sif}"
DATA_DIR="${DATA_DIR:-/projects/bbarn4-ic/medicaid/data}"
CONFIG_FILE="${CONFIG_FILE:-/workspace/configs/medicaid_config.yaml}"

# Command-line arguments (with defaults)
RUN_ID="${1:-production_$(date +%Y%m%d_%H%M%S)}"
MANIFEST="${2:-/projects/bbarn4-ic/medicaid/data/processed/manifests/production.list}"
OUTPUT_DIR="${3:-${DATA_DIR}/output/${RUN_ID}}"

# Processing parameters (adjust based on your batch_small.sh results)
MAX_WORKERS="${MAX_WORKERS:-8}"          # Parallel workers (increase with more GPUs)
CHECKPOINT_INTERVAL="${CHECKPOINT_INTERVAL:-25}"  # Save progress every N files
CHUNK_SIZE="${CHUNK_SIZE:-100}"          # Process in chunks for better progress tracking

# Resume capability
RESUME="${RESUME:-true}"                 # Resume from checkpoint if available

################################################################################
# Job Information
################################################################################

echo "================================================================================"
echo "PRODUCTION RUN: Full Dataset Processing"
echo "================================================================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Job Name: $SLURM_JOB_NAME"
echo "Node: $(hostname)"
echo "GPUs: $SLURM_GPUS_PER_NODE (GPU nodes)"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: 512GB"
echo "Time Limit: 48 hours"
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
echo "  Chunk Size: $CHUNK_SIZE"
echo "  Checkpoint Interval: Every $CHECKPOINT_INTERVAL files"
echo "  Resume from checkpoint: $RESUME"
echo ""

################################################################################
# Pre-Flight Checks
################################################################################

echo "Performing pre-flight checks..."
echo "--------------------------------------------------------------------------------"

# Create necessary directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "${OUTPUT_DIR}/logs"
mkdir -p "${OUTPUT_DIR}/checkpoints"
mkdir -p "${OUTPUT_DIR}/errors"

# Verify container exists
if [ ! -f "$CONTAINER_IMAGE" ]; then
    echo "ERROR: Container image not found at: $CONTAINER_IMAGE"
    echo "Please update the CONTAINER_IMAGE path in this script."
    exit 1
fi
echo "✓ Container image found"

# Verify manifest exists
if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: Manifest file not found at: $MANIFEST"
    echo ""
    echo "The manifest file should contain one PDF path per line."
    echo "Please create the manifest file or provide a valid path."
    exit 1
fi
echo "✓ Manifest file found"

# Count PDFs in manifest
PDF_COUNT=$(wc -l < "$MANIFEST")
echo "✓ Found $PDF_COUNT PDFs in manifest"

if [ "$PDF_COUNT" -eq 0 ]; then
    echo "ERROR: Manifest file is empty"
    exit 1
fi

# Check for existing checkpoint
CHECKPOINT_FILE="${OUTPUT_DIR}/checkpoints/latest.checkpoint"
if [ "$RESUME" = "true" ] && [ -f "$CHECKPOINT_FILE" ]; then
    echo "✓ Found checkpoint file - will resume from last saved position"
    COMPLETED_COUNT=$(grep -c "^completed:" "$CHECKPOINT_FILE" 2>/dev/null || echo "0")
    echo "  Previously completed: $COMPLETED_COUNT PDFs"
    REMAINING=$((PDF_COUNT - COMPLETED_COUNT))
    echo "  Remaining: $REMAINING PDFs"
else
    echo "✓ Starting fresh run (no checkpoint found or resume disabled)"
    COMPLETED_COUNT=0
    REMAINING=$PDF_COUNT
fi

# Estimate GPU-hours needed
if [ "$PDF_COUNT" -gt 0 ] && [ -n "${TIME_PER_PDF:-}" ]; then
    # If you know average time per PDF from batch_small.sh, set TIME_PER_PDF
    est_hours=$((PDF_COUNT * TIME_PER_PDF / 3600))
    est_gpu_hours=$((est_hours * SLURM_GPUS_PER_NODE))
    echo ""
    echo "Estimated GPU-hours: $est_gpu_hours (you have 1,000 allocated)"
    
    if [ "$est_gpu_hours" -gt 1000 ]; then
        echo "WARNING: Estimated usage may exceed allocation!"
        echo "Consider processing in multiple batches."
    fi
fi

echo ""
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
nvidia-smi --query-gpu=index,name,memory.total,memory.free,utilization.gpu --format=csv,noheader,nounits
echo ""

################################################################################
# Display Processing Plan
################################################################################

echo "Processing Plan:"
echo "--------------------------------------------------------------------------------"
echo "Total PDFs to process: $PDF_COUNT"
echo "Already completed: $COMPLETED_COUNT"
echo "Remaining to process: $REMAINING"
echo "Estimated chunks: $((REMAINING / CHUNK_SIZE + 1))"
echo ""

echo "Sample of PDFs to process (first 10):"
head -n 10 "$MANIFEST" | nl -w 4 -s '. '
if [ "$PDF_COUNT" -gt 10 ]; then
    echo "  ... and $((PDF_COUNT - 10)) more"
fi
echo ""

################################################################################
# Progress Monitoring Setup
################################################################################

# Create progress file
PROGRESS_FILE="${OUTPUT_DIR}/progress.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') | Production run started | Job ID: $SLURM_JOB_ID" > "$PROGRESS_FILE"

# Function to log progress
log_progress() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" | tee -a "$PROGRESS_FILE"
}

# Function to send progress updates
update_progress() {
    local completed=$1
    local total=$2
    local percent=$((completed * 100 / total))
    log_progress "Progress: $completed/$total PDFs ($percent%)"
}

################################################################################
# Error Recovery Setup
################################################################################

# Trap signals for graceful shutdown
trap 'log_progress "Job interrupted - checkpoint saved to $CHECKPOINT_FILE"; exit 130' INT TERM

# Error handler
handle_error() {
    local error_msg="$1"
    local pdf_file="${2:-unknown}"
    
    log_progress "ERROR processing $pdf_file: $error_msg"
    
    # Log error details
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $pdf_file | $error_msg" >> "${OUTPUT_DIR}/errors/error_log.txt"
    
    # Don't exit - continue with next file
    return 0
}

################################################################################
# Run Augmentoolkit Pipeline
################################################################################

echo "================================================================================"
echo "Starting Augmentoolkit Production Pipeline"
echo "================================================================================"
log_progress "Beginning production processing of $REMAINING PDFs"
echo ""

# Track start time
START_TIME=$SECONDS

# Run Augmentoolkit with the container
# --nv: Enable NVIDIA GPU support
# --bind: Mount directories from host to container
#
# Processing flags:
#   --resume: Resume from checkpoint if available
#   --checkpoint-interval: Save progress every N files
#   --error-handling: Continue on errors, don't stop the whole job
#   --max-retries: Retry failed files up to N times
#   --timeout: Timeout per PDF (prevents hanging on problematic files)

set +e  # Don't exit on errors - we want to continue processing

apptainer exec --nv \
    --bind "${DATA_DIR}:/workspace/data" \
    "$CONTAINER_IMAGE" \
    python -m augmentoolkit.processing \
        --config "$CONFIG_FILE" \
        --manifest "$MANIFEST" \
        --output "$OUTPUT_DIR" \
        --run-id "$RUN_ID" \
        --max-workers "$MAX_WORKERS" \
        --chunk-size "$CHUNK_SIZE" \
        --checkpoint-interval "$CHECKPOINT_INTERVAL" \
        --checkpoint-file "$CHECKPOINT_FILE" \
        --resume-from-checkpoint "$RESUME" \
        --error-handling continue \
        --max-retries 3 \
        --timeout-per-pdf 1800 \
        --log-level INFO \
        --progress-callback "echo" \
        2>&1 | while IFS= read -r line; do
            echo "$line"
            # Extract progress if available
            if echo "$line" | grep -q "Processed.*PDFs"; then
                update_progress "$(echo "$line" | grep -oP '\d+(?=/))" "$PDF_COUNT"
            fi
        done

# Capture exit status
PIPELINE_EXIT=$?

set -e  # Re-enable exit on error

# Calculate processing time
ELAPSED=$((SECONDS - START_TIME))

################################################################################
# Job Completion and Results Analysis
################################################################################

echo ""
echo "================================================================================"
echo "Production Run Completed"
echo "================================================================================"
echo "Finished at: $(date)"
echo ""

# Format elapsed time
days=$((ELAPSED / 86400))
hours=$(((ELAPSED % 86400) / 3600))
minutes=$(((ELAPSED % 3600) / 60))
seconds=$((ELAPSED % 60))

echo "Total processing time: ${days}d ${hours}h ${minutes}m ${seconds}s"
echo ""

# Calculate GPU-hours used
gpu_hours=$(echo "scale=2; $ELAPSED * $SLURM_GPUS_PER_NODE / 3600" | bc)
echo "GPU-hours consumed: $gpu_hours"
echo ""

################################################################################
# Output Analysis
################################################################################

log_progress "Analyzing output files..."

echo "Output Location: $OUTPUT_DIR"
echo ""

if [ -d "$OUTPUT_DIR" ] && [ "$(ls -A $OUTPUT_DIR 2>/dev/null)" ]; then
    echo "Output Summary:"
    echo "--------------------------------------------------------------------------------"
    
    # Count generated files by type
    json_count=$(find "$OUTPUT_DIR" -name "*.json" -type f 2>/dev/null | wc -l)
    jsonl_count=$(find "$OUTPUT_DIR" -name "*.jsonl" -type f 2>/dev/null | wc -l)
    log_count=$(find "$OUTPUT_DIR" -name "*.log" -type f 2>/dev/null | wc -l)
    
    echo "  JSON files: $json_count"
    echo "  JSONL files: $jsonl_count"
    echo "  Log files: $log_count"
    echo ""
    
    # Show directory size
    output_size=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
    echo "  Total output size: $output_size"
    echo ""
    
    # Count QA pairs if main output file exists
    MAIN_OUTPUT="${OUTPUT_DIR}/dataset.jsonl"
    if [ -f "$MAIN_OUTPUT" ]; then
        qa_pairs=$(wc -l < "$MAIN_OUTPUT")
        echo "  Generated QA pairs: $qa_pairs"
        
        # Calculate average QA pairs per PDF
        if [ "$PDF_COUNT" -gt 0 ]; then
            avg_qa=$((qa_pairs / PDF_COUNT))
            echo "  Average QA pairs per PDF: $avg_qa"
        fi
        echo ""
    fi
else
    echo "WARNING: Output directory is empty or missing."
    echo ""
fi

################################################################################
# Error Analysis
################################################################################

ERROR_LOG="${OUTPUT_DIR}/errors/error_log.txt"
if [ -f "$ERROR_LOG" ]; then
    error_count=$(wc -l < "$ERROR_LOG")
    echo "Errors encountered: $error_count"
    
    if [ "$error_count" -gt 0 ]; then
        echo ""
        echo "Most common errors (top 5):"
        echo "--------------------------------------------------------------------------------"
        cut -d'|' -f3- "$ERROR_LOG" | sort | uniq -c | sort -rn | head -n 5
        echo ""
        echo "Full error log: $ERROR_LOG"
    fi
    echo ""
else
    echo "✓ No errors logged"
    echo ""
fi

################################################################################
# Quality Metrics
################################################################################

if [ "$PDF_COUNT" -gt 0 ] && [ "$ELAPSED" -gt 0 ]; then
    echo "Performance Metrics:"
    echo "--------------------------------------------------------------------------------"
    
    # Calculate throughput
    pdfs_per_hour=$(echo "scale=2; $PDF_COUNT * 3600 / $ELAPSED" | bc)
    echo "  Processing rate: $pdfs_per_hour PDFs/hour"
    
    # Calculate average time per PDF
    avg_seconds=$(echo "scale=2; $ELAPSED / $PDF_COUNT" | bc)
    echo "  Average time per PDF: $avg_seconds seconds"
    
    # Calculate cost efficiency (if applicable)
    if [ -n "${COST_PER_GPU_HOUR:-}" ]; then
        total_cost=$(echo "scale=2; $gpu_hours * $COST_PER_GPU_HOUR" | bc)
        cost_per_pdf=$(echo "scale=4; $total_cost / $PDF_COUNT" | bc)
        echo "  Estimated cost: \$$total_cost"
        echo "  Cost per PDF: \$$cost_per_pdf"
    fi
    
    echo ""
fi

################################################################################
# Next Steps and Recommendations
################################################################################

echo "Next Steps:"
echo "--------------------------------------------------------------------------------"

if [ "$PIPELINE_EXIT" -eq 0 ]; then
    log_progress "Production run completed successfully!"
    echo "1. ✓ Pipeline completed successfully"
    echo "2. Review generated dataset: $OUTPUT_DIR/dataset.jsonl"
    echo "3. Validate QA quality with sample review"
    echo "4. Check dataset statistics: $OUTPUT_DIR/stats/"
    echo "5. If satisfied, proceed with model training"
else
    log_progress "Production run completed with errors (exit code: $PIPELINE_EXIT)"
    echo "1. ⚠ Pipeline completed with errors"
    echo "2. Review error log: $ERROR_LOG"
    echo "3. Check incomplete/failed PDFs in checkpoint: $CHECKPOINT_FILE"
    echo "4. Consider re-running with RESUME=true to process failed files"
    echo "5. Review logs: logs/production-$SLURM_JOB_ID.out"
fi

echo ""
echo "Logs and debugging:"
echo "  - Main log: logs/production-$SLURM_JOB_ID.out"
echo "  - Error log: logs/production-$SLURM_JOB_ID.err"
echo "  - Progress log: $PROGRESS_FILE"
echo "  - Checkpoint: $CHECKPOINT_FILE"
echo ""

################################################################################
# Resource Usage Summary
################################################################################

echo "Resource Usage Summary:"
echo "--------------------------------------------------------------------------------"
sacct -j $SLURM_JOB_ID --format=JobID,JobName,Partition,AllocCPUS,AllocGRES,State,ExitCode,Elapsed,MaxRSS,MaxVMSize 2>/dev/null | head -n 10 || echo "sacct not available"
echo ""

# Final GPU status
echo "Final GPU Status:"
echo "--------------------------------------------------------------------------------"
nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits
echo ""

echo "================================================================================"
echo "Production run finished at: $(date)"
echo "================================================================================"
