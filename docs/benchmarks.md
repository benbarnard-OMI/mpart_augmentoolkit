# Performance Benchmarks and Estimates

> **Last Updated**: 2025-11-04  
> **Status**: Template - To be filled during project execution

## Overview

This document tracks performance benchmarks across local and cluster environments for the Medicaid QA generation pipeline. Use this to:
- Record actual performance metrics
- Estimate GPU hours for remaining work
- Identify bottlenecks and optimization opportunities
- Compare performance across different configurations

## Table of Contents

- [Benchmark Targets](#benchmark-targets)
- [Recording Guidelines](#recording-guidelines)
- [Local Environment Benchmarks](#local-environment-benchmarks)
- [Campus Cluster Benchmarks](#campus-cluster-benchmarks)
- [Performance Comparison](#performance-comparison)
- [Optimization Insights](#optimization-insights)
- [GPU Hour Projections](#gpu-hour-projections)
- [Cost Estimates](#cost-estimates)

---

## Benchmark Targets

### Key Metrics to Track
| Metric | Unit | Purpose |
|--------|------|---------|
| Processing Time per PDF | minutes | Estimate total runtime |
| QA Pairs per PDF | count | Validate output volume |
| GPU Utilization | percentage | Optimize resource usage |
| Memory Usage (GPU) | GB | Prevent OOM errors |
| Memory Usage (CPU) | GB | Right-size allocations |
| GPU-Hours per PDF | hours | Budget tracking |
| Throughput | PDFs/hour | Capacity planning |
| Quality Score | 1-5 scale | Ensure quality maintained at scale |

### Environments
1. **Local Development**: Dual RTX 3090 (24GB each)
2. **Campus Cluster**: A100 80GB (high-memory nodes)

---

## Recording Guidelines

### Before Each Benchmark Run
- [ ] Document exact configuration (commit SHA, config file)
- [ ] Note hardware specifications
- [ ] Record model checkpoint and version
- [ ] Specify dataset subset being processed

### During Benchmark Run
- [ ] Monitor GPU utilization (nvidia-smi -l 1)
- [ ] Monitor memory usage
- [ ] Log processing timestamps
- [ ] Track error rates

### After Benchmark Run
- [ ] Calculate aggregate statistics
- [ ] Review output quality (sample 10-20 QA pairs)
- [ ] Document anomalies or issues
- [ ] Update projections based on results

### Data to Record
For each run, capture:
```yaml
benchmark_run:
  id: "local_test_2025-11-04_001"
  date: "2025-11-04"
  environment: "local" # or "cluster"
  commit_sha: "abc123def456"
  config_file: "configs/medicaid_config.yaml"
  
  hardware:
    gpu_model: "NVIDIA RTX 3090"
    gpu_count: 2
    gpu_vram_gb: 24
    cpu_cores: 16
    ram_gb: 64
    
  dataset:
    pdfs_processed: 10
    markdown_size_mb: 45
    
  model:
    name: "meta-llama/Llama-3.1-70B-Instruct"
    serving: "vLLM"
    tensor_parallel: 2
    
  configuration:
    chunk_size: 1500
    questions_per_chunk: 5
    concurrency_limit: 20
    
  results:
    total_time_minutes: 87
    qa_pairs_generated: 52
    avg_time_per_pdf_minutes: 8.7
    throughput_pdfs_per_hour: 6.9
    gpu_hours: 2.9
    avg_gpu_utilization_percent: 78
    max_gpu_memory_gb: 21
    avg_cpu_memory_gb: 32
    
  quality:
    sample_size: 20
    avg_clarity_score: 4.2
    avg_accuracy_score: 4.5
    avg_relevance_score: 4.3
    overall_acceptance_rate: 0.95
    
  issues:
    - "Minor: 2 PDFs had encoding warnings"
    - "No critical issues"
```

---

## Local Environment Benchmarks

### Local Test 1: Initial Validation
_To be filled after Phase 1 completion_

**Configuration:**
- **Date**: [YYYY-MM-DD]
- **Environment**: Local workstation (dual RTX 3090)
- **Config**: `configs/medicaid_config.yaml` (subset mode)
- **Commit SHA**: [git commit]

**Dataset:**
- **PDFs Processed**: 5
- **Source**: Sample set from `data/processed/sample/`

**Results:**
| Metric | Value | Notes |
|--------|-------|-------|
| Total Processing Time | ___ minutes | |
| Avg Time per PDF | ___ minutes | |
| QA Pairs Generated | ___ | Target: ~25-30 |
| QA Pairs per PDF | ___ | Target: ~5 |
| Throughput | ___ PDFs/hour | |
| GPU Utilization (Avg) | ___% | Target: >60% |
| GPU Memory (Max) | ___ GB | Per GPU |
| CPU Memory (Avg) | ___ GB | |
| GPU-Hours per PDF | ___ hours | |

**Quality Metrics:**
| Metric | Score (1-5) |
|--------|-------------|
| Question Clarity | ___ |
| Answer Accuracy | ___ |
| Source Relevance | ___ |
| Overall Quality | ___ |

**Issues Encountered:**
- [ ] None
- [ ] List issues here

**Lessons Learned:**
- _Note any configuration adjustments needed_
- _Optimization opportunities identified_

---

### Local Test 2: Scaled Sample (20 PDFs)
_To be filled after Phase 1 Task 1.4_

**Configuration:**
- **Date**: [YYYY-MM-DD]
- **Environment**: Local workstation (dual RTX 3090)
- **Config**: `configs/medicaid_config.yaml` (full settings)
- **Commit SHA**: [git commit]

**Dataset:**
- **PDFs Processed**: 20
- **Source**: Diverse sample from full dataset

**Results:**
| Metric | Value | Notes |
|--------|-------|-------|
| Total Processing Time | ___ minutes | |
| Avg Time per PDF | ___ minutes | |
| QA Pairs Generated | ___ | Target: ~100 |
| QA Pairs per PDF | ___ | Target: ~5 |
| Throughput | ___ PDFs/hour | |
| GPU Utilization (Avg) | ___% | |
| GPU Memory (Max) | ___ GB | Per GPU |
| CPU Memory (Avg) | ___ GB | |
| GPU-Hours per PDF | ___ hours | |
| Total GPU-Hours | ___ hours | |

**Quality Metrics:**
| Metric | Score (1-5) |
|--------|-------------|
| Question Clarity | ___ |
| Answer Accuracy | ___ |
| Source Relevance | ___ |
| Overall Quality | ___ |

**Projection for 1,100 PDFs:**
- **Estimated Time**: ___ hours (wall time on local)
- **Estimated GPU-Hours**: ___ hours
- **Estimated QA Pairs**: ___ pairs

---

## Campus Cluster Benchmarks

### Cluster Test 1: Smoke Test (Single PDF)
_To be filled after Phase 3 smoke test_

**Configuration:**
- **Date**: [YYYY-MM-DD]
- **Environment**: Campus Cluster (A100 80GB)
- **Job ID**: [Slurm job ID]
- **Config**: `configs/medicaid_config.yaml`
- **Commit SHA**: [git commit]

**Hardware:**
- **Node**: [node name]
- **GPU**: A100 80GB
- **CPUs**: [count]
- **Memory**: [GB allocated]

**Results:**
| Metric | Value | Notes |
|--------|-------|-------|
| Total Processing Time | ___ minutes | |
| QA Pairs Generated | ___ | Target: ~5 |
| GPU Utilization (Avg) | ___% | |
| GPU Memory (Max) | ___ GB | |
| CPU Memory (Max) | ___ GB | |
| GPU-Hours | ___ hours | |
| Job Efficiency (seff) | ___% | |

**Verification:**
- [ ] Output format correct
- [ ] GPU access working
- [ ] vLLM endpoint accessible
- [ ] No cluster-specific errors

---

### Cluster Test 2: Batch 50
_To be filled after Phase 4.1_

**Configuration:**
- **Date**: [YYYY-MM-DD]
- **Environment**: Campus Cluster (A100 80GB)
- **Job ID**: [Slurm job ID]
- **Config**: `configs/medicaid_config.yaml`
- **Commit SHA**: [git commit]

**Dataset:**
- **PDFs Processed**: 50
- **Manifest**: `data/processed/manifests/batch_50.txt`

**Results:**
| Metric | Value | Notes |
|--------|-------|-------|
| Total Processing Time | ___ hours | Wall time |
| Avg Time per PDF | ___ minutes | |
| QA Pairs Generated | ___ | Target: ~250 |
| QA Pairs per PDF | ___ | |
| Throughput | ___ PDFs/hour | |
| GPU Utilization (Avg) | ___% | |
| GPU Memory (Max) | ___ GB | |
| CPU Memory (Max) | ___ GB | |
| GPU-Hours per PDF | ___ hours | |
| Total GPU-Hours | ___ hours | |
| Job Efficiency | ___% | From seff |

**Quality Metrics:**
| Metric | Score (1-5) | Sample Size |
|--------|-------------|-------------|
| Question Clarity | ___ | 20 |
| Answer Accuracy | ___ | 20 |
| Source Relevance | ___ | 20 |
| Overall Quality | ___ | 20 |

**Projection for 1,100 PDFs:**
- **Estimated Time**: ___ hours (wall time)
- **Estimated GPU-Hours**: ___ hours
- **Within Budget**: Yes / No (1,000 hour budget)

---

### Cluster Test 3: Batch 200
_To be filled after Phase 4.2_

**Configuration:**
- **Date**: [YYYY-MM-DD]
- **Environment**: Campus Cluster (A100 80GB)
- **Job ID**: [Slurm job ID]
- **Commit SHA**: [git commit]

**Dataset:**
- **PDFs Processed**: 200
- **Manifest**: `data/processed/manifests/batch_200.txt`

**Results:**
| Metric | Value | Notes |
|--------|-------|-------|
| Total Processing Time | ___ hours | |
| Avg Time per PDF | ___ minutes | |
| QA Pairs Generated | ___ | Target: ~1,000 |
| QA Pairs per PDF | ___ | |
| Throughput | ___ PDFs/hour | |
| GPU Utilization (Avg) | ___% | |
| GPU Memory (Max) | ___ GB | |
| CPU Memory (Max) | ___ GB | |
| GPU-Hours per PDF | ___ hours | |
| Total GPU-Hours | ___ hours | |
| Job Efficiency | ___% | |

**Scaling Analysis:**
- **Time per PDF stable?**: Yes / No
- **Quality maintained?**: Yes / No
- **Any performance degradation?**: Yes / No

---

### Cluster Test 4: Batch 500
_To be filled after Phase 4.3_

**Configuration:**
- **Date**: [YYYY-MM-DD]
- **Environment**: Campus Cluster (A100 80GB)
- **Job ID(s)**: [Slurm job ID(s)]
- **Commit SHA**: [git commit]

**Dataset:**
- **PDFs Processed**: 500
- **Manifest**: `data/processed/manifests/batch_500.txt`

**Results:**
| Metric | Value | Notes |
|--------|-------|-------|
| Total Processing Time | ___ hours | |
| Avg Time per PDF | ___ minutes | |
| QA Pairs Generated | ___ | Target: ~2,500 |
| QA Pairs per PDF | ___ | |
| Throughput | ___ PDFs/hour | |
| GPU Utilization (Avg) | ___% | |
| GPU Memory (Max) | ___ GB | |
| CPU Memory (Max) | ___ GB | |
| GPU-Hours per PDF | ___ hours | |
| Total GPU-Hours | ___ hours | |
| Job Efficiency | ___% | |

**Quality Sample (n=50):**
| Metric | Score (1-5) |
|--------|-------------|
| Question Clarity | ___ |
| Answer Accuracy | ___ |
| Source Relevance | ___ |
| Overall Quality | ___ |

**Go/No-Go Decision for Production:**
- [ ] Performance within expectations
- [ ] Quality maintained at scale
- [ ] GPU hours projection acceptable
- [ ] No critical issues detected

---

### Production Run: Complete Dataset
_To be filled after Phase 4.4_

**Configuration:**
- **Date**: [YYYY-MM-DD]
- **Environment**: Campus Cluster (A100 80GB)
- **Job ID(s)**: [Slurm job ID(s)]
- **Commit SHA**: [git commit]

**Dataset:**
- **PDFs Processed**: ~600 (remaining)
- **Manifest**: `data/processed/manifests/production.txt`

**Results:**
| Metric | Value | Notes |
|--------|-------|-------|
| Total Processing Time | ___ hours | |
| Avg Time per PDF | ___ minutes | |
| QA Pairs Generated | ___ | |
| QA Pairs per PDF | ___ | |
| Throughput | ___ PDFs/hour | |
| GPU-Hours per PDF | ___ hours | |
| Total GPU-Hours | ___ hours | |
| Job Efficiency | ___% | |

**Cumulative Totals (All Batches):**
| Metric | Value |
|--------|-------|
| Total PDFs Processed | ___ / 1,100 |
| Total QA Pairs | ___ |
| Total GPU-Hours Used | ___ / 1,000 |
| GPU Hour Budget Remaining | ___ |
| Overall Success Rate | ___% |

---

## Performance Comparison

### Local vs. Cluster Performance
_To be filled after completing both environments_

| Metric | Local (RTX 3090 x2) | Cluster (A100 80GB) | Cluster Advantage |
|--------|---------------------|---------------------|-------------------|
| Avg Time per PDF | ___ min | ___ min | ___x faster |
| GPU Memory Available | 48 GB (total) | 80 GB | +32 GB |
| Throughput | ___ PDFs/hr | ___ PDFs/hr | ___x faster |
| GPU-Hours per PDF | ___ | ___ | ___x more efficient |
| Cost per PDF | $0 (owned) | $___ | N/A |

**Key Insights:**
- _Compare efficiency and cost-effectiveness_
- _Note any quality differences_
- _Recommend optimal environment for different use cases_

---

### Configuration Comparisons
_Fill in if testing multiple configurations_

**Experiment: Concurrency Limit Impact**

| Concurrency | Time/PDF (min) | GPU Util (%) | Quality | Notes |
|-------------|----------------|--------------|---------|-------|
| 10 | ___ | ___% | ___ | Baseline |
| 20 | ___ | ___% | ___ | Default |
| 50 | ___ | ___% | ___ | Aggressive |
| 100 | ___ | ___% | ___ | Max |

**Optimal Setting**: ___

**Experiment: Chunk Size Impact**

| Chunk Size | Time/PDF (min) | QA Pairs/PDF | Quality | Notes |
|------------|----------------|--------------|---------|-------|
| 1000 | ___ | ___ | ___ | Small |
| 1500 | ___ | ___ | ___ | Default |
| 2000 | ___ | ___ | ___ | Large |
| 3000 | ___ | ___ | ___ | Very Large |

**Optimal Setting**: ___

---

## Optimization Insights

### Bottlenecks Identified
_Document performance bottlenecks discovered during benchmarking_

1. **[Bottleneck Type]**
   - **Symptom**: _Description_
   - **Impact**: _Effect on performance_
   - **Root Cause**: _Analysis_
   - **Solution**: _Optimization applied_
   - **Improvement**: ___% faster / ___% better utilization

2. **[Another Bottleneck]**
   - _..._

### Optimization Strategies Applied

#### Concurrency Tuning
- **Initial Setting**: ___
- **Optimized Setting**: ___
- **Improvement**: ___% faster
- **Rationale**: _Explanation_

#### Memory Management
- **Initial**: ___
- **Optimized**: ___
- **Improvement**: _Description_
- **Rationale**: _Explanation_

#### Batch Sizing
- **Initial**: ___
- **Optimized**: ___
- **Improvement**: ___
- **Rationale**: _Explanation_

### Best Practices Discovered
1. _Best practice 1_
2. _Best practice 2_
3. _Best practice 3_

---

## GPU Hour Projections

### Current Usage Summary
_Update after each batch_

| Batch | PDFs | GPU-Hours Used | Cumulative GPU-Hours | Remaining Budget |
|-------|------|----------------|----------------------|------------------|
| Local Test | 20 | ___ | ___ | 1,000 |
| Smoke Test | 1 | ___ | ___ | ___ |
| Batch 50 | 50 | ___ | ___ | ___ |
| Batch 200 | 200 | ___ | ___ | ___ |
| Batch 500 | 500 | ___ | ___ | ___ |
| Production | ~600 | ___ | ___ | ___ |
| **Total** | **1,100** | **___** | **___** | **___** |

### Projection Model
Based on benchmarks, GPU-hour consumption follows:

```
GPU-Hours = (PDFs × Avg_GPU_Hours_per_PDF) + Overhead

Where:
  Avg_GPU_Hours_per_PDF = ___ hours (from benchmarks)
  Overhead = ~10% (startup, job scheduling, failures)
```

**Projected Total**: ___ GPU-hours for 1,100 PDFs

**Budget Status**:
- ✅ Within budget (<1,000 hours)
- ⚠️ Close to budget (900-1,000 hours)
- ❌ Over budget (>1,000 hours) - need to optimize or request extension

---

## Cost Estimates

### Campus Cluster Costs
_If applicable - many academic clusters don't charge directly_

**GPU-Hour Rate**: $___/hour (A100 80GB)

| Scenario | PDFs | GPU-Hours | Cost |
|----------|------|-----------|------|
| Best Case (efficient) | 1,100 | ___ | $___ |
| Expected Case | 1,100 | ___ | $___ |
| Worst Case (inefficient) | 1,100 | ___ | $___ |

### Commercial Cloud Alternatives
_For comparison_

**AWS p4d.24xlarge (A100 80GB x8)**:
- **Rate**: ~$32/hour
- **Effective rate per GPU**: ~$4/hour
- **Projected cost**: $___ for 1,100 PDFs

**Google Cloud A2 (A100 80GB)**:
- **Rate**: ~$3.67/hour per GPU
- **Projected cost**: $___ for 1,100 PDFs

**Azure NCv4 (A100 80GB)**:
- **Rate**: ~$3.06/hour per GPU
- **Projected cost**: $___ for 1,100 PDFs

**Campus Cluster Savings**: $___ vs. commercial cloud

---

## Benchmark Templates

### Quick Benchmark Template
Use this for rapid testing:

```yaml
run_id: test_[date]_[number]
date: YYYY-MM-DD
pdfs: [count]
time_minutes: [total]
qa_pairs: [count]
gpu_hours: [total]
quality_ok: yes/no
issues: [list or "none"]
```

### Detailed Benchmark Template
Use this for formal benchmarking:

```yaml
benchmark_run:
  id: "[environment]_[description]_[date]"
  date: "YYYY-MM-DD"
  environment: "local" | "cluster"
  
  hardware:
    gpu_model: "[model]"
    gpu_count: [N]
    gpu_vram_gb: [GB]
    
  configuration:
    commit_sha: "[SHA]"
    config_file: "[path]"
    chunk_size: [size]
    questions_per_chunk: [N]
    concurrency_limit: [N]
    
  dataset:
    pdfs_processed: [N]
    manifest: "[path]"
    
  results:
    total_time_minutes: [minutes]
    avg_time_per_pdf_minutes: [minutes]
    qa_pairs_generated: [count]
    qa_pairs_per_pdf: [average]
    throughput_pdfs_per_hour: [rate]
    gpu_hours: [total]
    avg_gpu_utilization_percent: [%]
    max_gpu_memory_gb: [GB]
    avg_cpu_memory_gb: [GB]
    
  quality_sample:
    sample_size: [N]
    avg_clarity_score: [1-5]
    avg_accuracy_score: [1-5]
    avg_relevance_score: [1-5]
    acceptance_rate: [0-1]
    
  issues: [list or "none"]
```

---

## Lessons Learned

### Performance Insights
_Document key learnings about performance optimization_

1. **[Insight Title]**
   - **Finding**: _Description_
   - **Impact**: _Quantified impact_
   - **Recommendation**: _Action item_

### Quality-Performance Tradeoffs
_Document any tradeoffs discovered_

1. **[Tradeoff]**
   - **Description**: _What was traded_
   - **Decision**: _What was chosen and why_

---

## Outstanding Questions

_Track questions to investigate in future benchmarking_

- [ ] Question 1
- [ ] Question 2
- [ ] Question 3

---

## Next Steps

After completing benchmarks:

1. **Update Projections**: Refine GPU-hour estimates for remaining work
2. **Document Optimizations**: Record all configuration improvements
3. **Report Findings**: Share key insights with team
4. **Archive Data**: Save all benchmark logs and results
5. **Update Documentation**: Incorporate learnings into other docs

---

**Last Updated**: 2025-11-04  
**Primary Contact**: Ben Barnard  
**Review Frequency**: After each major batch (50, 200, 500, production)
