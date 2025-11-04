# Medicaid QA Dataset Generation

> **Last Updated**: 2025-11-04

Generate a high-quality question-answer dataset from roughly 1,100 Medicaid policy PDFs using Augmentoolkit and the UIUC Campus Cluster. This repository centralizes the project plan, benchmarking docs, job scripts, and environment configuration so the pipeline is reproducible from local prototyping through full production runs.

## Project Status

- 🟡 **Phase**: Local Development & Testing
- 📊 **PDFs Processed**: 0 / 1,100
- ⚡ **GPU Hours Used**: 0 / 1,000
- 🎯 **Next Milestone**: Docker build and local validation

## Quick Facts

- **Goal**: Produce production-ready QA pairs suitable for fine-tuning LLMs while staying within a 1,000 GPU-hour allocation
- **Team Lead**: Ben Barnard
- **Timeline**: 6-8 weeks
- **Compute**: Local dual RTX 3090 workstations + Illinois Campus Cluster (A100 80GB, 5TB storage)
- **Target Output**: ~5,500+ high-quality QA pairs from 1,100 Medicaid policy PDFs
- **Model**: Llama 3.1 70B via vLLM

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Resource Tracking](#resource-tracking)
- [Documentation](#documentation)
- [Phase Plan and Deliverables](#phase-plan-and-deliverables)
- [Environments and Tooling](#environments-and-tooling)
- [Risk Management](#risk-management)
- [Success Metrics](#success-metrics)
- [Team](#team)
- [License](#license)

## Prerequisites

Before getting started with this project, ensure you have access to the following:

### Hardware & Software
- **Local Development**:
  - Linux workstation with NVIDIA GPU(s) (tested with dual RTX 3090 24GB)
  - CUDA 12.1+ drivers installed
  - Docker with NVIDIA Container Toolkit
  - At least 100GB free disk space for models and data
- **Campus Cluster Access**:
  - UIUC Campus Cluster account with GPU allocation
  - Access to high-memory A100 80GB nodes
  - 5TB storage allocation for project data

### Required Tools
- **Docker** (version 20.10+) with NVIDIA GPU support
- **Git** for version control
- **Python 3.10+** for local testing
- **Apptainer/Singularity** (pre-installed on Campus Cluster)

### API Keys & Credentials
- **vLLM API endpoint** or local vLLM setup for Llama 3.1 70B
- **LLAMA_API_KEY** environment variable (if using API)
- **Campus Cluster credentials** (NetID and login)
- Optional: **Hugging Face token** for model downloads
- Optional: **W&B API key** for experiment tracking

### Knowledge Prerequisites
- Basic understanding of Docker containerization
- Familiarity with Slurm job scheduling (for cluster deployment)
- Experience with Python and YAML configuration files
- Basic understanding of LLM inference and fine-tuning workflows

## Quick Start

Get up and running in 5 minutes:

### 1. Clone the Repository
```bash
git clone https://github.com/your-org/medicaid-qa-generation.git
cd medicaid-qa-generation
```

### 2. Build Docker Image
```bash
docker build -t mpart-augmentoolkit:v1 .
```

### 3. Test GPU Access
```bash
docker run --gpus all mpart-augmentoolkit:v1 nvidia-smi
```

### 4. Run Environment Test
```bash
docker run --gpus all \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/configs:/workspace/configs \
  mpart-augmentoolkit:v1 \
  python /workspace/scripts/test_environment.py
```

### 5. Process Sample PDFs
```bash
# Convert a few sample PDFs to markdown (adjust paths as needed)
docker run --gpus all \
  -v $(pwd)/data:/workspace/data \
  mpart-augmentoolkit:v1 \
  python /workspace/scripts/preprocessing/convert_pdfs.py \
  --input-dir /workspace/data/raw \
  --output-dir /workspace/data/processed/sample \
  --limit 5
```

⚠️ **Important**: For production runs, you'll need a running vLLM server with Llama 3.1 70B. See [docs/setup.md](docs/setup.md) for detailed setup instructions.

💡 **Tip**: Start with 5-10 sample PDFs locally before scaling to the full 1,100 PDF dataset on the cluster.

## Project Structure

```
medicaid-qa-generation/
├── configs/                        # Configuration files
│   ├── augmentoolkit_config.yaml  # Main Augmentoolkit configuration (deprecated)
│   └── medicaid_config.yaml       # Medicaid-specific QA generation config (USE THIS)
│
├── data/                          # Data storage (gitignored)
│   ├── raw/                       # Original 1,100 Medicaid policy PDFs
│   ├── processed/                 # Converted markdown files from PDFs
│   │   └── manifests/            # PDF batch manifests for Slurm jobs
│   └── output/                   # Generated QA pairs and logs
│
├── docs/                          # Documentation
│   ├── setup.md                  # Local development setup guide
│   ├── campus_cluster_deployment.md  # Cluster deployment instructions
│   ├── workflow.md               # End-to-end processing workflow
│   ├── troubleshooting.md        # Common issues and solutions
│   ├── benchmarks.md             # Performance metrics and benchmarks
│   └── dataset_card.md           # Dataset metadata and documentation
│
├── scripts/                       # Utility scripts
│   ├── preprocessing/            # PDF preprocessing tools
│   │   └── convert_pdfs.py      # Docling-based PDF to markdown converter
│   ├── slurm/                    # Campus Cluster job scripts
│   │   ├── test_single.sh       # Single-PDF smoke test
│   │   ├── batch_50.sh          # 50-PDF batch validation
│   │   ├── batch_small.sh       # Small batch testing
│   │   ├── production.sh        # Full production run script
│   │   ├── test_single_pdf.sh   # Alternative single PDF test
│   │   ├── test_environment.sh  # Environment validation
│   │   └── README.md            # Slurm scripts documentation
│   └── test_environment.py       # Python environment validation script
│
├── logs/                          # Runtime logs (created automatically)
│
├── Dockerfile                     # Container definition for reproducibility
├── requirements.txt               # Python dependencies
├── LICENSE                        # Project license
└── README.md                      # This file
```

### Key Directories Explained

- **`configs/`**: Contains YAML configuration files for Augmentoolkit. Use `medicaid_config.yaml` for all production runs.
- **`data/`**: All data files (PDFs, markdown, outputs) go here. This directory is not version-controlled.
- **`docs/`**: Comprehensive documentation covering setup, deployment, troubleshooting, and workflows.
- **`scripts/`**: Automation scripts for PDF preprocessing and cluster job submission.
- **`scripts/slurm/`**: Slurm batch scripts for running jobs on the Campus Cluster with different batch sizes.

💡 **Tip**: Keep `data/` and `logs/` out of git by using the provided `.gitignore`.

## Development Workflow

This project follows a systematic development workflow from local prototyping to full production deployment:

### Local Development & Testing
1. **Environment Setup** → Build Docker container and validate GPU access
2. **PDF Preprocessing** → Convert sample PDFs (5-20) to markdown using Docling
3. **Pipeline Testing** → Run Augmentoolkit on samples with `medicaid_config.yaml`
4. **Benchmarking** → Measure performance metrics (time/PDF, GPU utilization)
5. **Quality Review** → Manually inspect generated QA pairs for accuracy

### Campus Cluster Deployment
6. **Container Transfer** → Push Docker image and convert to Apptainer format
7. **Data Upload** → Transfer PDFs and markdown files to cluster storage
8. **Smoke Testing** → Run single-PDF test with `test_single.sh`
9. **Incremental Scaling** → Process batches of 50 → 200 → 500 PDFs
10. **Production Run** → Process remaining ~600 PDFs with `production.sh`

### Quality Assurance & Finalization
11. **QA Validation** → Review random samples (100+ pairs) for accuracy
12. **Dataset Preparation** → Format output for fine-tuning (train/val/test splits)
13. **Documentation** → Finalize all docs, benchmarks, and dataset card
14. **Handoff** → Prepare repository for team collaboration and future use

For detailed step-by-step instructions, see:
- [docs/setup.md](docs/setup.md) - Local development setup
- [docs/campus_cluster_deployment.md](docs/campus_cluster_deployment.md) - Cluster deployment
- [docs/workflow.md](docs/workflow.md) - Complete processing workflow

## Resource Tracking

### GPU-Hour Budget
- **Allocated**: 1,000 GPU-hours on UIUC Campus Cluster (A100 80GB nodes)
- **Used**: _To be tracked during production runs_
- **Remaining**: _To be updated weekly_

Track actual usage in `docs/benchmarks.md` after each batch run.

### Processing Progress
| Phase | PDFs Processed | QA Pairs Generated | GPU-Hours Used | Status |
|-------|---------------|-------------------|----------------|--------|
| Phase 1 (Local Testing) | 0 / 20 | 0 / ~100 | ~2-5 | Not Started |
| Phase 2 (Smoke Test) | 0 / 1 | 0 / ~5 | ~0.1 | Not Started |
| Phase 3 (Batch 50) | 0 / 50 | 0 / ~250 | ~10-15 | Not Started |
| Phase 3 (Batch 200) | 0 / 200 | 0 / ~1,000 | ~40-60 | Not Started |
| Phase 3 (Batch 500) | 0 / 500 | 0 / ~2,500 | ~100-150 | Not Started |
| Phase 4 (Production) | 0 / ~600 | 0 / ~3,000 | ~120-180 | Not Started |
| **Total** | **0 / 1,100** | **0 / ~5,500** | **~272-410** | **In Planning** |

⚠️ **Important**: Update this table after each batch completes. If projections exceed 800 GPU-hours by Phase 3, reassess batch sizes and optimization strategies.

### Data Storage
- **Cluster Allocation**: 5TB
- **Estimated Usage**:
  - Raw PDFs: ~50GB
  - Processed Markdown: ~30GB
  - Generated QA Datasets: ~5GB
  - Logs & Metadata: ~2GB
  - Model Cache: ~150GB
  - **Total**: ~237GB (well within allocation)

## Documentation

Comprehensive documentation for every aspect of the project:

| Document | Description | Audience |
|----------|-------------|----------|
| [README.md](README.md) | Project overview and quick start | Everyone |
| [docs/setup.md](docs/setup.md) | Local development setup | Developers |
| [docs/campus_cluster_deployment.md](docs/campus_cluster_deployment.md) | Cluster deployment guide | DevOps/ML Engineers |
| [docs/workflow.md](docs/workflow.md) | End-to-end processing workflow | Team Leads |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common issues and solutions | All Users |
| [docs/benchmarks.md](docs/benchmarks.md) | Performance metrics | Researchers |
| [docs/dataset_card.md](docs/dataset_card.md) | Dataset metadata | Data Scientists |
| [scripts/slurm/README.md](scripts/slurm/README.md) | Slurm script documentation | Cluster Users |

💡 **Tip**: Start with `setup.md` for local testing, then move to `campus_cluster_deployment.md` for production runs.

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

## Team

### Core Contributors
- **Ben Barnard** - Project Lead & Principal Investigator
- _Add team members here as they join the project_

### Roles & Responsibilities
- **Project Lead**: Overall project direction, stakeholder communication, final decisions
- **ML Engineer**: Pipeline development, model configuration, optimization
- **Data Engineer**: PDF preprocessing, data validation, storage management
- **QA Specialist**: Quality assurance, manual review of generated QA pairs
- **DevOps**: Cluster deployment, job scheduling, infrastructure management

### Contributing
This is an internal research project. For questions or collaboration inquiries, please contact:
- **Primary Contact**: Ben Barnard
- **Slack Channel**: `#medicaid-qa` (internal team workspace)
- **Email**: _Add project email if available_

### Acknowledgments
- **UIUC Campus Cluster** team for infrastructure support and GPU allocation
- **Augmentoolkit** project by E.P. Armstrong for the QA generation framework
- **Docling** team for PDF-to-markdown conversion tools
- **vLLM** project for efficient LLM inference

## License

This project is licensed under the [LICENSE](LICENSE) file in this repository.

### Source Document Licensing
The Medicaid policy PDFs used in this project are public documents provided by state agencies. However, before distributing any derived datasets:
1. Verify licensing terms for source documents
2. Ensure compliance with data usage agreements
3. Add appropriate disclaimers for informational use only
4. Consult with legal counsel regarding public release

### Third-Party Components
- **Augmentoolkit**: Licensed under its respective open-source license
- **Llama 3.1 70B**: Subject to Meta's Llama 3.1 Community License
- **vLLM**: Apache 2.0 License
- **Docling**: Licensed under its respective terms

⚠️ **Important**: This dataset is intended for research and educational purposes only. Generated QA pairs should not be used for legal advice or clinical decision-making without appropriate human oversight.

---

## Next Steps

Ready to get started? Follow this path:

1. ✅ **Read this README** to understand the project (you're here!)
2. 📖 **Review [docs/setup.md](docs/setup.md)** to set up your local environment
3. 🧪 **Run local tests** with sample PDFs to validate your setup
4. 📚 **Read [docs/workflow.md](docs/workflow.md)** to understand the complete pipeline
5. 🚀 **Deploy to cluster** using [docs/campus_cluster_deployment.md](docs/campus_cluster_deployment.md)
6. 📊 **Track progress** in [docs/benchmarks.md](docs/benchmarks.md)
7. ❓ **Troubleshoot issues** with [docs/troubleshooting.md](docs/troubleshooting.md)

### Immediate Action Items
- [ ] Populate manifests under `data/processed/manifests/` for sample, batch, and production runs
- [ ] Record baseline benchmarks after completing Phase 1 Task 1.4
- [ ] Set up vLLM server with Llama 3.1 70B for inference
- [ ] Configure environment variables (`LLAMA_API_KEY`, `VLLM_BASE_URL`)
- [ ] Upload sample PDFs to `data/raw/` for initial testing

### Questions?
Check [docs/troubleshooting.md](docs/troubleshooting.md) first, then reach out to the team on Slack or via the contacts listed in the [Team](#team) section.

---

**Last Updated**: 2025-11-04 | **Version**: 1.0 | **Status**: 📝 Documentation Complete, Ready for Phase 1
