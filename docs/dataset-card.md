# Medicaid QA Dataset - Dataset Card (Draft)

## Dataset Overview
- **Title**: Medicaid Policy QA Synthetic Dataset
- **Creators**: Medicaid QA Generation Team (Lead: Ben Barnard)
- **Source Documents**: ~1,100 Medicaid policy PDFs provided by state agencies.
- **Collection Period**: TBD (record during Phase 1 data preparation).
- **Languages**: English (verify and document exceptions).

## Motivation
- Support fine-tuning of question-answering models on Medicaid policy content.
- Provide reproducible benchmarks for healthcare policy QA tasks.

## Composition
- **Instances**: QA pairs generated from policy PDFs.
- **Fields**: `id`, `question`, `answer`, `source_pdf`, `page_reference`, `confidence`, `metadata`.
- **Annotation**: Semi-automated via Augmentoolkit with human validation on samples.
- **Sensitive Content**: Policies may reference protected health information guidelines; no personally identifiable information is expected.

## Collection Process
- **Pipeline**: Docling (PDF to Markdown) -> Augmentoolkit QA generation with Llama 3.1 70B via vLLM/Ollama.
- **Filtering**: Document heuristics and manual QA review criteria in `docs/quality-assurance.md` (to be added).
- **Quality Checks**: Manual evaluation of random samples (Phase 4 Task 4.2).

## Preprocessing
- Markdown normalization, chunking, prompt templating, post-processing for answer formatting.
- Track preprocessing parameters in `configs/augmentoolkit_config.yaml` and Slurm job scripts.

## Uses
- **Intended**: Fine-tuning and evaluating QA models on Medicaid policy content.
- **Out-of-scope**: Clinical decision making, legal advice without human oversight.

## Distribution
- **Hosting**: TBD (Illinois secure storage / internal registry).
- **Access**: Controlled; follow data sharing agreements.
- **License**: Align with source documents; confirm prior to release.

## Maintenance
- **Lead Maintainer**: Ben Barnard
- **Update Schedule**: Review annually or upon major policy refresh.
- **Contact**: medicaid-qa@project.org

## Ethical Considerations
- Ensure responses do not misrepresent legal requirements.
- Include disclaimers regarding use for informational purposes only.
- Evaluate bias stemming from state-specific policy differences.

## TODOs Before Release
- Document QA validation metrics and reviewer notes.
- Finalize train/validation/test splits in `data/output/splits`.
- Add dataset versioning scheme (for example semantic tags or commit hashes).
