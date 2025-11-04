# Complete Processing Workflow

> **Last Updated**: 2025-11-04

This document provides a comprehensive overview of the end-to-end processing workflow for generating the Medicaid QA dataset, from raw PDFs to production-ready training data.

## Table of Contents

- [Workflow Overview](#workflow-overview)
- [Phase 1: PDF Preprocessing](#phase-1-pdf-preprocessing-docling)
- [Phase 2: Local Testing](#phase-2-local-testing-docker)
- [Phase 3: Cluster Deployment](#phase-3-cluster-deployment-apptainer)
- [Phase 4: QA Generation](#phase-4-qa-generation-augmentoolkit)
- [Phase 5: Quality Validation](#phase-5-quality-validation)
- [Phase 6: Dataset Preparation](#phase-6-dataset-preparation-for-fine-tuning)
- [Timeline and Resource Estimates](#timeline-and-resource-estimates)
- [Decision Points](#decision-points)
- [Rollback Procedures](#rollback-procedures)

---

## Workflow Overview

### High-Level Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                        MEDICAID QA GENERATION                        │
│                         Complete Workflow                            │
└─────────────────────────────────────────────────────────────────────┘

    ┌───────────────┐
    │ 1,100 Medicaid│
    │ Policy PDFs   │
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │   Phase 1:    │
    │ PDF → Markdown│  (Docling Conversion)
    │   ~2 hours    │
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │   Phase 2:    │
    │ Local Testing │  (Docker + 5-20 samples)
    │   ~4 hours    │
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │   Phase 3:    │
    │   Cluster     │  (Apptainer Setup)
    │   Deployment  │
    │   ~2 hours    │
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │   Phase 4:    │
    │      QA       │  (Augmentoolkit + Llama 70B)
    │  Generation   │  ~40-60 GPU-hours
    │   ~2-3 days   │
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │   Phase 5:    │
    │   Quality     │  (Manual Review)
    │  Validation   │  ~8 hours
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │   Phase 6:    │
    │   Dataset     │  (Train/Val/Test Splits)
    │  Preparation  │  ~2 hours
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │ ~5,500 QA     │
    │ Pairs Ready   │
    │ for Training  │
    └───────────────┘
```

---

## Phase 1: PDF Preprocessing (Docling)

### Overview
Convert 1,100 Medicaid policy PDFs to markdown format for Augmentoolkit processing.

### Prerequisites
- [x] All PDFs collected and organized
- [x] Docling installed (via Docker image)
- [x] Sufficient storage (~50GB for PDFs + 30GB for markdown)

### Steps

#### 1.1 Organize Source PDFs
```bash
# Place all PDFs in data/raw/
ls -lh data/raw/*.pdf | wc -l  # Should show 1100
```

#### 1.2 Run Docling Conversion
```bash
# Convert all PDFs to markdown
docker run --gpus all \
  -v $(pwd)/data:/workspace/data \
  mpart-augmentoolkit:v1 \
  python /workspace/scripts/preprocessing/convert_pdfs.py \
  --input-dir /workspace/data/raw \
  --output-dir /workspace/data/processed \
  --parallel 4

# Expected output: data/processed/*.md (1,100 files)
```

#### 1.3 Verify Conversion Quality
```bash
# Check conversion rate
ls data/processed/*.md | wc -l

# Sample review
for file in $(ls data/processed/*.md | shuf -n 5); do
    echo "=== $file ==="
    head -50 "$file"
done
```

#### 1.4 Handle Conversion Failures
```bash
# Identify failed conversions
diff <(ls data/raw/*.pdf | sed 's/.pdf$//' | sort) \
     <(ls data/processed/*.md | sed 's/.md$//' | sort) \
     > conversion_failures.txt

# Retry failures manually or with adjusted parameters
```

### Outputs
- ✅ `data/processed/*.md` - 1,100 markdown files
- ✅ `data/processed/logs/conversion.log` - Conversion logs
- ✅ `conversion_failures.txt` - List of failed conversions (if any)

### Time Estimate
- **Serial**: ~5-6 hours (3-4 seconds per PDF)
- **Parallel (4 processes)**: ~2 hours
- **With GPU acceleration**: ~1 hour

### Quality Checks
- [ ] Markdown files have proper headers
- [ ] Tables converted correctly
- [ ] No major sections missing
- [ ] Special characters handled properly
- [ ] File sizes reasonable (not empty or truncated)

---

## Phase 2: Local Testing (Docker)

### Overview
Validate the complete pipeline on a small sample locally before deploying to the cluster.

### Prerequisites
- [x] Docker image built
- [x] vLLM server running (or API access configured)
- [x] GPU access verified

### Steps

#### 2.1 Prepare Sample Dataset
```bash
# Select 5-10 diverse PDFs for testing
mkdir -p data/processed/sample
cp data/processed/policy_001.md data/processed/sample/
cp data/processed/policy_050.md data/processed/sample/
cp data/processed/policy_100.md data/processed/sample/
# ... add 2-7 more
```

#### 2.2 Configure for Testing
```yaml
# Edit configs/medicaid_config.yaml
system:
  use_subset: True
  subset_size: 30  # Process only 30 chunks
  concurrency_limit: 20  # Safe for local GPUs

path:
  input_dirs:
    - path: /workspace/data/processed/sample
      factual_gen_use_subset: True
```

#### 2.3 Start vLLM Server (Local)
```bash
# In separate terminal
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-70B-Instruct \
  --tensor-parallel-size 2 \
  --gpu-memory-utilization 0.9 \
  --port 8000
```

#### 2.4 Run Augmentoolkit
```bash
# Set environment variables
export LLAMA_API_KEY=""  # Leave blank for local
export VLLM_BASE_URL="http://localhost:8000/v1"
export LLAMA_MODEL="meta-llama/Llama-3.1-70B-Instruct"

# Run pipeline
docker run --gpus all \
  --network host \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/configs:/workspace/configs \
  -v $(pwd)/logs:/workspace/logs \
  -e LLAMA_API_KEY="${LLAMA_API_KEY}" \
  -e VLLM_BASE_URL="${VLLM_BASE_URL}" \
  -e LLAMA_MODEL="${LLAMA_MODEL}" \
  mpart-augmentoolkit:v1 \
  augmentoolkit --config /workspace/configs/medicaid_config.yaml
```

#### 2.5 Monitor Progress
```bash
# Watch logs
tail -f logs/latest.log

# Monitor GPU usage
watch -n 1 nvidia-smi
```

#### 2.6 Review Sample Output
```bash
# Check generated QA pairs
cat data/output/dataset.jsonl | jq '.' | less

# Count QA pairs
wc -l data/output/dataset.jsonl

# Expected: 25-50 QA pairs from 5-10 sample PDFs
```

### Outputs
- ✅ `data/output/dataset.jsonl` - Sample QA pairs
- ✅ `logs/latest.log` - Processing logs
- ✅ Benchmarks recorded in `docs/benchmarks.md`

### Time Estimate
- **Setup**: 1 hour
- **Processing 5 PDFs**: 30-60 minutes
- **Review**: 1-2 hours
- **Total**: ~3-4 hours

### Quality Checks
- [ ] QA pairs generated successfully
- [ ] Questions are relevant and specific
- [ ] Answers are accurate and well-sourced
- [ ] Source citations present
- [ ] No obvious hallucinations
- [ ] Formatting is consistent

### Decision Point 1: Proceed to Cluster?
**Criteria to proceed:**
- ✅ All quality checks passed
- ✅ Configuration validated
- ✅ Benchmarks acceptable (time per PDF < 10 min)
- ✅ Output quality >80% acceptable

**If not ready:** Return to Phase 1 or adjust configuration.

---

## Phase 3: Cluster Deployment (Apptainer)

### Overview
Transfer the validated pipeline to UIUC Campus Cluster for production-scale processing.

### Prerequisites
- [x] Campus Cluster access configured
- [x] Docker image pushed to registry
- [x] Storage allocation available

### Steps

#### 3.1 Push Docker Image
```bash
# Tag and push
docker tag mpart-augmentoolkit:v1 yourusername/mpart-augmentoolkit:v1
docker push yourusername/mpart-augmentoolkit:v1
```

#### 3.2 Set Up Cluster Environment
```bash
# SSH to cluster
ssh cc-login

# Create directory structure
cd /projects/yourgroup/medicaid-qa
mkdir -p data/{processed,output} configs scripts/slurm logs

# Pull Apptainer image
apptainer pull docker://yourusername/mpart-augmentoolkit:v1
```

#### 3.3 Transfer Data
```bash
# From local machine
rsync -avz --progress data/processed/ \
  cc-login:/projects/yourgroup/medicaid-qa/data/processed/

rsync -avz configs/ \
  cc-login:/projects/yourgroup/medicaid-qa/configs/

rsync -avz scripts/slurm/ \
  cc-login:/projects/yourgroup/medicaid-qa/scripts/slurm/
```

#### 3.4 Configure vLLM Endpoint
Option A: Request managed vLLM service from cluster
Option B: Deploy vLLM in separate Slurm job

#### 3.5 Update Slurm Scripts
```bash
# Edit scripts/slurm/test_single.sh
# Update paths, account name, vLLM endpoint
```

#### 3.6 Smoke Test (Single PDF)
```bash
# Create test manifest
echo "/projects/yourgroup/medicaid-qa/data/processed/policy_001.md" > data/processed/manifests/test_single.txt

# Submit test job
sbatch scripts/slurm/test_single.sh

# Monitor
squeue -u $USER
tail -f logs/test-single-*.out
```

#### 3.7 Validate Smoke Test
```bash
# Check output
ls -lh data/output/
cat data/output/dataset.jsonl | wc -l  # Should have 5-10 QA pairs

# Verify job efficiency
seff JOBID
```

### Outputs
- ✅ Apptainer image on cluster
- ✅ All data transferred
- ✅ Smoke test successful
- ✅ Slurm scripts validated

### Time Estimate
- **Setup and Transfer**: 1-2 hours
- **Smoke Test**: 30 minutes
- **Validation**: 30 minutes
- **Total**: ~2-3 hours

### Decision Point 2: Scale Up?
**Criteria to proceed:**
- ✅ Smoke test passed
- ✅ GPU access working
- ✅ vLLM endpoint accessible
- ✅ Output format correct

**If not ready:** Debug cluster-specific issues before scaling.

---

## Phase 4: QA Generation (Augmentoolkit)

### Overview
Process all 1,100 Medicaid PDFs in incremental batches on the cluster.

### Prerequisites
- [x] Smoke test successful
- [x] GPU hours allocated
- [x] Monitoring set up

### Steps

#### 4.1 Batch 50 (Validation)
```bash
# Create manifest
ls /projects/yourgroup/medicaid-qa/data/processed/*.md | head -50 > data/processed/manifests/batch_50.txt

# Submit job
sbatch scripts/slurm/batch_50.sh

# Record start time
echo "Batch 50 started at $(date)" >> logs/timeline.txt
```

**Monitor and validate output before proceeding.**

#### 4.2 Batch 200 (Scaling Test)
```bash
# Create manifest
ls /projects/yourgroup/medicaid-qa/data/processed/*.md | head -200 > data/processed/manifests/batch_200.txt

# Submit job
sbatch scripts/slurm/batch_200.sh
```

**Validate GPU hour projections before proceeding.**

#### 4.3 Batch 500 (Pre-Production)
```bash
# Create manifest
ls /projects/yourgroup/medicaid-qa/data/processed/*.md | head -500 > data/processed/manifests/batch_500.txt

# Submit job (may use job array)
sbatch scripts/slurm/batch_500.sh
```

**Final quality check before full production.**

#### 4.4 Production (Remaining ~600 PDFs)
```bash
# Create manifest for remaining PDFs
comm -23 \
  <(ls /projects/yourgroup/medicaid-qa/data/processed/*.md | sort) \
  <(cat data/processed/manifests/batch_500.txt | sort) \
  > data/processed/manifests/production.txt

# Submit production job array
sbatch scripts/slurm/production.sh
```

#### 4.5 Monitor Production Run
```bash
# Check job status
watch -n 60 'squeue -u $USER'

# Monitor GPU hours
sreport cluster UserUtilizationByAccount Start=$(date -d "7 days ago" +%Y-%m-%d) -t hours

# Check output growth
watch -n 300 'wc -l /projects/yourgroup/medicaid-qa/data/output/dataset.jsonl'
```

#### 4.6 Handle Failures
```bash
# Identify failed PDFs
# Compare manifest with processed output
# Resubmit failed PDFs in separate job
```

### Outputs
- ✅ `data/output/dataset.jsonl` - All QA pairs (~5,500)
- ✅ `logs/production-*.out` - Processing logs
- ✅ `data/output/metadata.json` - Generation metadata
- ✅ Updated `docs/benchmarks.md`

### Time Estimate (Wall Time)
- **Batch 50**: 2-3 hours
- **Batch 200**: 8-12 hours
- **Batch 500**: 20-30 hours
- **Production (~600)**: 24-36 hours
- **Total**: 54-81 hours (~3-4 days)

### GPU-Hours Estimate
- **Per PDF**: ~0.25-0.4 GPU-hours
- **1,100 PDFs**: ~275-440 GPU-hours
- **With overhead**: ~300-500 GPU-hours

### Decision Point 3: Quality Acceptable?
**Criteria to proceed:**
- ✅ >90% of PDFs processed successfully
- ✅ Output quality >85% acceptable (from sampling)
- ✅ GPU hours within budget
- ✅ No major issues detected

**If not ready:** Investigate quality issues, potentially reprocess problem batches.

---

## Phase 5: Quality Validation

### Overview
Manual and automated review of generated QA pairs to ensure quality standards.

### Steps

#### 5.1 Automated Validation
```bash
# Run validation script
python scripts/validate_qa_dataset.py \
  --input data/output/dataset.jsonl \
  --output data/output/validation_report.json

# Check for:
# - Missing fields
# - Empty answers
# - Duplicate questions
# - Invalid JSON
```

#### 5.2 Statistical Analysis
```bash
# Generate statistics
python scripts/dataset_statistics.py \
  --input data/output/dataset.jsonl

# Review:
# - Total QA pairs
# - Average question length
# - Average answer length
# - Source distribution
# - Topic distribution (if tagged)
```

#### 5.3 Manual Sampling and Review
```bash
# Sample 100 random QA pairs
shuf -n 100 data/output/dataset.jsonl > data/output/manual_review_sample.jsonl

# Review criteria:
# 1. Question clarity (1-5)
# 2. Answer accuracy (1-5)
# 3. Source relevance (1-5)
# 4. Overall quality (1-5)
```

Create review spreadsheet:
| ID | Question | Answer | Source | Q_Clarity | A_Accuracy | S_Relevance | Overall | Notes |
|----|----------|--------|--------|-----------|------------|-------------|---------|-------|

#### 5.4 Identify Issues
```bash
# Categorize problems found:
# - Hallucinations
# - Vague questions
# - Irrelevant answers
# - Missing sources
# - Formatting issues
```

#### 5.5 Corrective Actions
- **Minor issues (<5%)**: Accept as-is, document in dataset card
- **Moderate issues (5-15%)**: Filter out poor quality pairs
- **Major issues (>15%)**: Reprocess problematic batches with adjusted config

### Outputs
- ✅ `data/output/validation_report.json` - Validation results
- ✅ `data/output/statistics.json` - Dataset statistics
- ✅ Manual review spreadsheet
- ✅ Filtered dataset (if needed)

### Time Estimate
- **Automated validation**: 30 minutes
- **Statistical analysis**: 30 minutes
- **Manual review (100 samples)**: 4-6 hours
- **Corrective actions**: 1-2 hours
- **Total**: ~8 hours

### Quality Targets
- **Question clarity**: Average >4.0/5
- **Answer accuracy**: Average >4.2/5
- **Source relevance**: Average >4.0/5
- **Overall quality**: >90% rated ≥3/5

---

## Phase 6: Dataset Preparation for Fine-Tuning

### Overview
Format the validated QA pairs into training-ready datasets with proper splits.

### Steps

#### 6.1 Filter Low-Quality Pairs
```bash
# If manual review identified poor pairs
python scripts/filter_dataset.py \
  --input data/output/dataset.jsonl \
  --exclude data/output/exclude_ids.txt \
  --output data/output/dataset_filtered.jsonl
```

#### 6.2 Create Train/Val/Test Splits
```bash
python scripts/create_splits.py \
  --input data/output/dataset_filtered.jsonl \
  --train-ratio 0.8 \
  --val-ratio 0.1 \
  --test-ratio 0.1 \
  --seed 42 \
  --output-dir data/output/splits/
```

Expected outputs:
- `data/output/splits/train.jsonl` (~4,400 pairs)
- `data/output/splits/val.jsonl` (~550 pairs)
- `data/output/splits/test.jsonl` (~550 pairs)

#### 6.3 Convert to Training Formats
```bash
# Convert to different formats as needed
# For example: Alpaca format, ShareGPT format, etc.

python scripts/convert_format.py \
  --input data/output/splits/train.jsonl \
  --format alpaca \
  --output data/output/splits/train_alpaca.json
```

#### 6.4 Calculate Dataset Statistics
```bash
python scripts/final_statistics.py \
  --train data/output/splits/train.jsonl \
  --val data/output/splits/val.jsonl \
  --test data/output/splits/test.jsonl \
  --output data/output/final_statistics.json
```

#### 6.5 Package for Distribution
```bash
# Create compressed archive
cd data/output/splits
tar -czvf medicaid_qa_dataset_v1.tar.gz *.jsonl

# Generate checksums
sha256sum *.jsonl > SHA256SUMS

# Create README
cat > README.txt <<EOF
Medicaid QA Dataset v1.0
Generated: $(date)
Total QA Pairs: $(wc -l train.jsonl val.jsonl test.jsonl | tail -1 | awk '{print $1}')

Files:
- train.jsonl: Training set
- val.jsonl: Validation set
- test.jsonl: Test set
- SHA256SUMS: Checksums for verification

See docs/dataset_card.md for full documentation.
EOF
```

### Outputs
- ✅ `data/output/splits/train.jsonl` - Training set
- ✅ `data/output/splits/val.jsonl` - Validation set
- ✅ `data/output/splits/test.jsonl` - Test set
- ✅ `data/output/final_statistics.json` - Final stats
- ✅ `data/output/splits/medicaid_qa_dataset_v1.tar.gz` - Packaged dataset
- ✅ Completed `docs/dataset_card.md`

### Time Estimate
- **Filtering**: 30 minutes
- **Splitting**: 15 minutes
- **Format conversion**: 30 minutes
- **Statistics**: 15 minutes
- **Packaging**: 30 minutes
- **Total**: ~2 hours

---

## Timeline and Resource Estimates

### Overall Project Timeline
| Phase | Duration (Wall Time) | GPU-Hours | Dependencies |
|-------|---------------------|-----------|--------------|
| Phase 1: PDF Preprocessing | 2 hours | 0 | None |
| Phase 2: Local Testing | 4 hours | 2-5 | Phase 1 |
| Phase 3: Cluster Deployment | 2 hours | 0.5 | Phase 2 |
| Phase 4: QA Generation | 3-4 days | 300-500 | Phase 3 |
| Phase 5: Quality Validation | 1 day | 0 | Phase 4 |
| Phase 6: Dataset Preparation | 2 hours | 0 | Phase 5 |
| **Total** | **5-6 days** | **302-505** | - |

### Critical Path
```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
(2h)      (4h)      (2h)      (72-96h)  (8h)      (2h)
```

---

## Decision Points

### Decision Point 1: After Local Testing (Phase 2)
**Question**: Is the pipeline ready for cluster deployment?

**Evaluation Criteria:**
- [ ] Output quality acceptable
- [ ] Configuration validated
- [ ] Benchmarks within expectations
- [ ] No critical errors

**Possible Outcomes:**
- ✅ **PROCEED**: Move to Phase 3
- ⚠️ **ITERATE**: Adjust config and retest
- ❌ **HALT**: Major issues require rethinking approach

---

### Decision Point 2: After Cluster Smoke Test (Phase 3)
**Question**: Is the cluster environment ready for production?

**Evaluation Criteria:**
- [ ] Smoke test successful
- [ ] Resource allocation sufficient
- [ ] Monitoring working
- [ ] No cluster-specific issues

**Possible Outcomes:**
- ✅ **PROCEED**: Start incremental scaling (Phase 4)
- ⚠️ **DEBUG**: Fix cluster issues before scaling
- ❌ **REVERT**: Return to local testing if major incompatibilities

---

### Decision Point 3: After Batch 500 (Phase 4)
**Question**: Should we proceed with full production?

**Evaluation Criteria:**
- [ ] Quality remains acceptable at scale
- [ ] GPU hour projections within budget
- [ ] No scaling issues observed
- [ ] Failure rate acceptable (<5%)

**Possible Outcomes:**
- ✅ **PROCEED**: Launch full production run
- ⚠️ **OPTIMIZE**: Adjust parameters for efficiency
- ❌ **HALT**: Reassess approach if problems detected

---

### Decision Point 4: After QA Generation (Phase 4)
**Question**: Is the dataset quality sufficient for fine-tuning?

**Evaluation Criteria:**
- [ ] Manual review >85% acceptable
- [ ] Automated validation passed
- [ ] Coverage of topics adequate
- [ ] No systematic issues

**Possible Outcomes:**
- ✅ **PROCEED**: Move to dataset packaging (Phase 6)
- ⚠️ **FILTER**: Remove low-quality pairs and proceed
- ❌ **REPROCESS**: Rerun problematic batches with better config

---

## Rollback Procedures

### If Issues Found in Phase 2 (Local Testing)
**Actions:**
1. Review logs and identify root cause
2. Adjust configuration parameters
3. Re-run on same sample
4. Document changes in `docs/benchmarks.md`

**No resource loss** (local testing only)

---

### If Issues Found in Phase 3 (Cluster Smoke Test)
**Actions:**
1. Debug on interactive node
2. Fix Slurm scripts or environment
3. Re-run smoke test
4. Update documentation

**Resource loss**: <1 GPU-hour

---

### If Issues Found in Phase 4 (Mid-Production)
**Actions:**
1. Cancel running jobs if critical issue
2. Identify affected batches
3. Fix configuration
4. Resubmit only affected batches
5. Resume from checkpoint if supported

**Resource loss**: Proportional to affected batches

---

### If Issues Found in Phase 5 (Quality Review)
**Options:**

**Option A: Filter** (if <15% problematic)
- Remove poor quality pairs
- Proceed with filtered dataset
- Document filtering in dataset card

**Option B: Reprocess** (if 15-50% problematic)
- Identify problematic PDF characteristics
- Adjust configuration
- Reprocess affected PDFs only

**Option C: Full Rerun** (if >50% problematic)
- Major configuration changes
- Reprocess all PDFs
- Requires new GPU hour allocation

---

## Success Criteria

### Quantitative Metrics
- [ ] ≥1,100 PDFs processed
- [ ] ≥5,000 QA pairs generated
- [ ] ≤500 GPU-hours consumed
- [ ] ≥90% processing success rate
- [ ] ≥85% quality acceptance rate

### Qualitative Metrics
- [ ] Questions are specific and answerable
- [ ] Answers are accurate and well-sourced
- [ ] Coverage of policy topics is comprehensive
- [ ] Format is consistent and parseable
- [ ] Documentation is complete

---

## Next Steps After Completion

1. **Fine-Tuning**: Use the dataset to fine-tune a base model
2. **Evaluation**: Test fine-tuned model on held-out test set
3. **Documentation**: Complete all docs, especially dataset card
4. **Presentation**: Prepare findings for symposium
5. **Publication**: Consider publishing dataset (with proper approvals)

---

**Questions?**
- Review specific phase docs: [setup.md](setup.md), [campus_cluster_deployment.md](campus_cluster_deployment.md)
- Check [troubleshooting.md](troubleshooting.md) for common issues
- Contact team on Slack #medicaid-qa
