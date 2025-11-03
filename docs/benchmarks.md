# Medicaid QA Dataset Generation - Benchmark Log

## Overview
- **Purpose**: Track performance benchmarks across local and cluster environments.
- **Key Metrics**: Time per PDF, GPU utilization, throughput, failure rate, output quality scores.
- **Owners**: Pipeline team; primary contact Ben Barnard.

## Benchmark Targets
- Local baseline (Phase 1) using dual RTX 3090 GPUs.
- Illinois Campus Cluster (Phase 2 onward) using A100 80GB GPUs.

## Recording Guidelines
- Document the exact configuration and commit SHA for every run.
- Capture command invocation, dataset subset, model checkpoint, and prompt configuration.
- Store raw logs in `data/output/logs/<date>-<run_id>.log` (to be created by pipeline).
- Summaries should include:
  - Processing throughput (PDFs/hour and QA pairs/hour).
  - GPU hours consumed and utilization percentages.
  - Notable bottlenecks or anomalies.
  - Suggested optimizations.

## Template
| Date | Environment | Dataset Size | Model | Avg. Time/PDF | GPU Utilization | GPU-Hours | Output Notes | Issues | Owner |
|------|-------------|--------------|-------|----------------|-----------------|-----------|--------------|--------|-------|
| YYYY-MM-DD | Local / Cluster | N PDFs | Llama 3.1 70B | HH:MM | % | X | Quality summary | Any blockers | Name |

## Outstanding Questions
- Ideal chunking strategy for 1,100 PDFs?
- Acceptable latency threshold per PDF at scale?
- Can we reuse embeddings across runs to save GPU-hours?

## Next Steps
- Populate baseline results after completing Phase 1 Task 1.4.
- Schedule follow-up benchmarking review ahead of Phase 3 medium batch run.
