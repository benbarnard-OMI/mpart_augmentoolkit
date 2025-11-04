#!/bin/bash
# Example: sbatch scripts/slurm/batch_50.sh run-2025-01-15 /projects/bbarn4-ic/medicaid/data/processed/batch_50.list

#SBATCH --job-name=medicaid-qa-50
#SBATCH --partition=IllinoisComputes-GPU
#SBATCH --account=bbarn4-ic
#SBATCH --gres=gpu:a100:1
#SBATCH --cpus-per-task=16
#SBATCH --mem=256G
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x-%j.out

set -euo pipefail

RUN_ID=${1:-batch_50}
MANIFEST=${2:-/projects/bbarn4-ic/medicaid/data/processed/manifests/batch_50.list}
OUTPUT_DIR=${3:-/projects/bbarn4-ic/medicaid/data/output/${RUN_ID}}
CONTAINER_IMAGE=${CONTAINER_IMAGE:-/projects/bbarn4-ic/containers/augmentoolkit-pipeline_latest.sif}

module purge
module load apptainer/latest

mkdir -p "${OUTPUT_DIR}" logs

echo "[$(date -Iseconds)] Starting 50-PDF batch run ${RUN_ID}"
echo "Manifest: ${MANIFEST}"

apptainer exec --nv \
    "${CONTAINER_IMAGE}" \
    augmentoolkit run \
      --config /workspace/configs/medicaid_config.yaml \
      --manifest "${MANIFEST}" \
      --output "${OUTPUT_DIR}" \
      --run-id "${RUN_ID}" \
      --max-workers 4 \
      --log-file "${OUTPUT_DIR}/run.log"

echo "[$(date -Iseconds)] Batch run complete. Review outputs at ${OUTPUT_DIR}"
