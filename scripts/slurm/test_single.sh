#!/bin/bash
# Example: sbatch scripts/slurm/test_single.sh test-run /projects/bbarn4-ic/medicaid/data/processed/sample.pdf

#SBATCH --job-name=medicaid-qa-test
#SBATCH --partition=IllinoisComputes-GPU
#SBATCH --account=bbarn4-ic
#SBATCH --gres=gpu:a100:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --time=02:00:00
#SBATCH --output=logs/%x-%j.out

set -euo pipefail

RUN_ID=${1:-test_single}
PDF_PATH=${2:-/projects/bbarn4-ic/medicaid/data/processed/sample.pdf}
OUTPUT_DIR=${3:-/projects/bbarn4-ic/medicaid/data/output/${RUN_ID}}
CONTAINER_IMAGE=${CONTAINER_IMAGE:-/projects/bbarn4-ic/containers/augmentoolkit-pipeline_latest.sif}

module purge
module load apptainer/latest

mkdir -p "${OUTPUT_DIR}" logs

echo "[$(date -Iseconds)] Starting single PDF QA generation for ${PDF_PATH}"

apptainer exec --nv \
    "${CONTAINER_IMAGE}" \
    augmentoolkit run \
      --config /workspace/configs/medicaid_config.yaml \
      --input "${PDF_PATH}" \
      --output "${OUTPUT_DIR}" \
      --run-id "${RUN_ID}" \
      --log-file "${OUTPUT_DIR}/run.log"

echo "[$(date -Iseconds)] Run complete. Outputs at ${OUTPUT_DIR}"
