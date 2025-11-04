#!/bin/bash
################################################################################
# SLURM Job Script: Environment Validation Test
################################################################################
#
# PURPOSE: Validate that the Apptainer container and GPU environment work
#          correctly on UIUC Campus Cluster before running actual processing.
#
# USAGE: sbatch scripts/slurm/test_environment.sh
#
# This is the FIRST script you should run on the cluster to ensure everything
# is configured correctly.
#
################################################################################

#SBATCH --job-name=augmentoolkit-test-env
#SBATCH --partition=IllinoisComputes-GPU
#SBATCH --account=bbarn4-ic
#SBATCH --nodes=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=00:10:00
#SBATCH --output=logs/test-env-%j.out
#SBATCH --error=logs/test-env-%j.err

################################################################################
# Script Settings
################################################################################

# Exit on any error
set -euo pipefail

# CUSTOMIZE THESE PATHS FOR YOUR SETUP
CONTAINER_IMAGE="${CONTAINER_IMAGE:-/projects/bbarn4-ic/containers/augmentoolkit-pipeline_latest.sif}"

################################################################################
# Job Information
################################################################################

echo "================================================================================"
echo "Environment Validation Test"
echo "================================================================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Job Name: $SLURM_JOB_NAME"
echo "Node: $(hostname)"
echo "Started at: $(date)"
echo "================================================================================"
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
# Container Information
################################################################################

echo "Container image: $CONTAINER_IMAGE"
echo ""

# Verify container exists
if [ ! -f "$CONTAINER_IMAGE" ]; then
    echo "ERROR: Container image not found at: $CONTAINER_IMAGE"
    echo "Please set the CONTAINER_IMAGE environment variable or update this script."
    exit 1
fi

################################################################################
# Run Environment Test
################################################################################

echo "Running environment validation tests..."
echo "--------------------------------------------------------------------------------"

# Run the test_environment.py script inside the container
# The --nv flag enables NVIDIA GPU support
apptainer exec --nv \
    "$CONTAINER_IMAGE" \
    python /workspace/scripts/test_environment.py

################################################################################
# Job Completion
################################################################################

echo ""
echo "================================================================================"
echo "Environment test completed successfully!"
echo "Finished at: $(date)"
echo "================================================================================"
echo ""
echo "Next steps:"
echo "1. Review the output above to ensure all tests passed"
echo "2. If successful, proceed to test_single_pdf.sh"
echo "3. If errors occurred, check the error log: logs/test-env-$SLURM_JOB_ID.err"
echo ""
