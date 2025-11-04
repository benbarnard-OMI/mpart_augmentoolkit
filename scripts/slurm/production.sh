#!/bin/bash
# Example: sbatch scripts/slurm/production.sh prod-2025-02-01 /projects/bbarn4-ic/medicaid/data/processed/manifests/production.list

#SBATCH --job-name=medicaid-qa-prod
#SBATCH --partition=IllinoisComputes-GPU
#SBATCH --account=bbarn4-ic
#SBATCH --gres=gpu:a100:1
#SBATCH --cpus-per-task=24
#SBATCH --mem=384G
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x-%j.out

set -euo pipefail

RUN_ID=${1:-production}
MANIFEST=${2:-/projects/bbarn4-ic/medicaid/data/processed/manifests/production.list}
OUTPUT_DIR=${3:-/projects/bbarn4-ic/medicaid/data/output/${RUN_ID}}
CHUNK_SIZE=${CHUNK_SIZE:-100}
CONTAINER_IMAGE=${CONTAINER_IMAGE:-/projects/bbarn4-ic/containers/augmentoolkit-pipeline_latest.sif}

module purge
module load apptainer/latest

mkdir -p "${OUTPUT_DIR}" logs

echo "[$(date -Iseconds)] Starting production run ${RUN_ID}"
echo "Manifest: ${MANIFEST}"
echo "Chunk size: ${CHUNK_SIZE}"

apptainer exec --nv \
    "${CONTAINER_IMAGE}" \
    augmentoolkit run \
      --config /workspace/configs/augmentoolkit_config.yaml \
      --manifest "${MANIFEST}" \
      --output "${OUTPUT_DIR}" \
      --run-id "${RUN_ID}" \
      --max-workers 6 \
      --chunk-size "${CHUNK_SIZE}" \
      --resume-on-failure \
      --log-file "${OUTPUT_DIR}/run.log"

echo "[$(date -Iseconds)] Production run submitted. Monitor progress via squeue and log files."
