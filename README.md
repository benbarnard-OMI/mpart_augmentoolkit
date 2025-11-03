# Medicaid QA Dataset Generation

Generate a high-quality question-answer dataset from roughly 1,100 Medicaid policy PDFs using Augmentoolkit and the UIUC Campus Cluster. This repository centralizes the project plan, benchmarking docs, job scripts, and environment configuration so the pipeline is reproducible from local prototyping through full production runs.

- **Goal**: Produce production-ready QA pairs suitable for fine-tuning LLMs while staying within a 1,000 GPU-hour allocation.
- **Team Lead**: Ben Barnard
- **Timeline**: 6-8 weeks
- **Compute**: Local dual RTX 3090 workstations + Illinois Campus Cluster (A100 80GB, 5TB storage)

## Project Structure

```
medicaid-qa-generation/
|-- configs/                 # Augmentoolkit and pipeline configs
|-- data/                    # Raw PDFs, processed markdown, QA outputs
|-- docs/                    # Benchmarks, troubleshooting, dataset card
|-- scripts/
|   |-- preprocessing/       # PDF conversion utilities
|   `-- slurm/               # Cluster job scripts
|-- Dockerfile               # Containerized runtime environment
|-- requirements.txt         # Python dependencies (Augmentoolkit installed separately)
`-- README.md
```

See `docs/dataset-card.md` for dataset metadata and `docs/troubleshooting.md` for operational runbooks.

## Phase Plan and Deliverables

### Phase 1 - Local Development and Testing (Weeks 1-2)
- Containerize environment (`Dockerfile`, `requirements.txt`).
- Convert 10-20 sample PDFs via `scripts/preprocessing/convert_pdfs.py`.
- Validate pipeline with `_LOCAL_DATAGEN_complete_factual.yaml` against 5 PDFs.
- Benchmark 20 PDFs locally and log metrics in `docs/benchmarks.md`.
- **Deliverables**: Local Docker image, baseline benchmarks, sampled QA outputs, updated configs.

### Phase 2 - Campus Cluster Integration (Week 3)
- Establish campus cluster access and storage provisioning.
- Pull container image via Apptainer (`scripts/slurm/test_single.sh`).
- Run single-PDF smoke test and validate GPU access.
- Draft Slurm scripts (`scripts/slurm/*.sh`) and document data paths.
- **Deliverables**: Validated Apptainer container, functional Slurm scripts, initial cluster QA outputs, troubleshooting notes.

### Phase 3 - Incremental Scaling (Week 4)
- Process 50-PDF batch using `batch_50.sh`; monitor GPU hours.
- Scale to 200-PDF batch; capture timing versus baseline.
- Execute 500-PDF batch; inspect storage utilization and QA quality.
- **Deliverables**: 500+ PDFs processed, updated benchmarks, refined job scripts, QA review summary.

### Phase 4 - Full Production Run (Weeks 5-6)
- Process remaining ~600 PDFs with `production.sh` and resume-on-failure logic.
- Track GPU usage, rerun failed jobs, and maintain operational logs.
- Perform manual QA on 100 sampled outputs; consolidate QA pairs into JSONL splits.
- **Deliverables**: Complete QA dataset, quality metrics, formatted training data, resource usage report.

### Phase 5 - Documentation and Handoff (Weeks 7-8)
- Author comprehensive documentation (README, config references, troubleshooting guides).
- Finalize dataset card, metadata, and distribution plan.
- Prepare presentation materials and visualizations for symposium demo.
- **Deliverables**: Documentation bundle, reproducibility playbook, presentation assets, GitHub-ready repository.

## Environments and Tooling

### Local Development
1. Clone Augmentoolkit alongside this repository.
2. `python3 -m venv .venv && source .venv/bin/activate`
3. `pip install -r requirements.txt`
4. `pip install -e ../augmentoolkit` (adjust path as necessary)
5. Run conversion tests: `python scripts/preprocessing/convert_pdfs.py --input-dir data/raw --output-dir data/processed/sample --limit 5`

### Container Workflow
```bash
# Build locally
docker build -t yourusername/augmentoolkit-pipeline:v1 .
# Validate GPU access
docker run --gpus all -it yourusername/augmentoolkit-pipeline:v1 nvidia-smi
# Push to registry for Campus Cluster use
docker push yourusername/augmentoolkit-pipeline:v1
```

On campus cluster:
```bash
apptainer pull docker://yourusername/augmentoolkit-pipeline:v1
apptainer exec --nv augmentoolkit-pipeline_latest.sif augmentoolkit --help
```

### Slurm Job Scripts
- `scripts/slurm/test_single.sh`: Smoke test for one PDF.
- `scripts/slurm/batch_50.sh`: Small-batch validation and monitoring.
- `scripts/slurm/production.sh`: Full pipeline execution with chunking and resume support.

Update `CONTAINER_IMAGE`, `MANIFEST`, and output paths before submission.

## Risk Management
- **GPU-hours overrun**: Track metrics per batch; escalate if projections exceed allocation.
- **QA quality gaps**: Enforce manual review at each scaling phase; iterate on prompts and configs.
- **Cluster instability**: Maintain run logs, leverage `docs/troubleshooting.md`, engage support early.
- **Storage delays**: Continue local benchmarking while storage is provisioned.

## Success Metrics
- 1,100 PDFs processed successfully.
- 90% or higher accuracy on manually reviewed QA pairs.
- 1,000 GPU-hours consumed or less.
- Reproducible pipeline with end-to-end documentation.

## Next Steps
- Populate manifests under `data/processed/manifests/` for sample, batch, and production runs.
- Record baseline benchmarks after completing Phase 1 Task 1.4.
- Draft `docs/quality-assurance.md` to capture review methodology (Phase 4 Task 4.2).
