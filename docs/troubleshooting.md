# Medicaid QA Dataset - Troubleshooting Guide

## Quick Reference
- **Slack Channel**: `#medicaid-qa`
- **Campus Cluster Help Desk**: help@campuscluster.illinois.edu
- **Primary Contacts**: Ben Barnard (lead), infra-oncall@project.org

## Common Issues

### Container / Environment
- **Symptom**: `nvidia-smi` not available inside container.
  - **Check**: Did you launch with `--gpus all` (Docker) or `--nv` (Apptainer)?
  - **Fix**: Restart container with proper GPU flags; verify host drivers.
- **Symptom**: Python package import errors.
  - **Check**: Is the Docker image up to date? Run `docker pull`.
  - **Fix**: Rebuild image locally and push; version-pin dependencies in `requirements.txt`.

### Data Conversion
- **Symptom**: Markdown output missing sections.
  - **Check**: Docling conversion logs in `data/processed/logs`.
  - **Fix**: Adjust conversion parameters; retry; flag problematic PDFs in `docs/conversion-issues.md` (to be created if needed).
- **Symptom**: Encoding errors during conversion.
  - **Check**: Ensure PDFs are UTF-8 compatible.
  - **Fix**: Use `pdfcpu` to sanitize or run through OCR pipeline.

### Pipeline Execution
- **Symptom**: Augmentoolkit run halts without error.
  - **Check**: Inspect `data/output/logs/latest.log`.
  - **Fix**: Increase logging level in `configs/augmentoolkit_config.yaml`; rerun with `--verbose`.
- **Symptom**: Llama 3.1 70B fails to load on cluster.
  - **Check**: Confirm Slurm job requested 80GB GPU (A100).
  - **Fix**: Increase `--gres=gpu:a100:1` and memory; verify Apptainer cache size.

### Slurm Jobs
- **Symptom**: Job pending indefinitely.
  - **Check**: `squeue -u <netid>` for reason; often `Priority` or `QOSMaxJobsPerUserLimit`.
  - **Fix**: Reduce concurrent jobs; contact cluster support for quota questions.
- **Symptom**: Job fails with `OUT_OF_MEMORY`.
  - **Check**: GPU/CPU memory usage in `.out` file.
  - **Fix**: Reduce batch size; request more memory via `#SBATCH --mem=256G`.

## Escalation
1. Log issue in `docs/troubleshooting.md` with date and owner.
2. Notify team in Slack with run ID and relevant logs.
3. If blocked more than 12 hours, escalate to Campus Cluster support with ticket including job scripts and logs.

## Lessons Learned (To Be Updated)
- Capture recurring issues and resolutions here for quick reference.
