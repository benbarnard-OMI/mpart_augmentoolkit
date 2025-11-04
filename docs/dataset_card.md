# Medicaid QA Dataset Card

> **Last Updated**: 2025-11-04  
> **Version**: 1.0  
> **Status**: In Development

## Table of Contents

- [Dataset Overview](#dataset-overview)
- [Dataset Description](#dataset-description)
- [Motivation](#motivation)
- [Dataset Composition](#dataset-composition)
- [Collection Process](#collection-process)
- [Preprocessing and Quality Control](#preprocessing-and-quality-control)
- [Dataset Statistics](#dataset-statistics)
- [Intended Uses](#intended-uses)
- [Out-of-Scope Uses](#out-of-scope-uses)
- [Dataset Structure](#dataset-structure)
- [Data Splits](#data-splits)
- [Source Documents](#source-documents)
- [Annotation Process](#annotation-process)
- [Quality Assurance](#quality-assurance)
- [Ethical Considerations](#ethical-considerations)
- [Limitations and Biases](#limitations-and-biases)
- [Distribution and Maintenance](#distribution-and-maintenance)
- [Citation](#citation)

---

## Dataset Overview

**Dataset Name**: Medicaid Policy Question-Answer (QA) Dataset  
**Language**: English  
**License**: [To be determined based on source document licensing]  
**Format**: JSONL (JSON Lines)

### Quick Facts
- **Source Documents**: ~1,100 Medicaid policy PDFs from state agencies
- **Generation Method**: Automated QA generation using Llama 3.1 70B via Augmentoolkit
- **Target Size**: ~5,500+ question-answer pairs
- **Domain**: Healthcare policy, specifically Medicaid regulations and guidelines
- **Primary Use**: Fine-tuning language models for Medicaid policy question answering

### Creators
- **Project Lead**: Ben Barnard
- **Institution**: University of Illinois at Urbana-Champaign
- **Project**: MPART (Medicaid Policy Analysis Research Tool)
- **Team**: [To be filled with contributor names]

---

## Dataset Description

This dataset contains synthetic question-answer pairs generated from Medicaid policy documents to support the development of AI systems capable of answering questions about Medicaid regulations, eligibility, benefits, and procedures.

### What is this dataset?
The Medicaid QA Dataset is a collection of question-answer pairs extracted from approximately 1,100 Medicaid policy PDF documents. Each QA pair is:
- **Grounded in source documents**: Answers are derived directly from policy text
- **Source-cited**: References to specific policy documents included
- **Diverse in format**: Includes open-ended questions, factual queries, and policy interpretation
- **Validated**: Subject to both automated and manual quality checks

### Why was this dataset created?
Medicaid policy is complex, varies by state, and changes frequently. This dataset aims to:
1. Enable development of AI assistants that can answer Medicaid-related questions accurately
2. Support policy research and analysis
3. Improve access to Medicaid information for beneficiaries, administrators, and researchers
4. Provide a benchmark for evaluating healthcare policy QA systems

---

## Motivation

### Problem Statement
Medicaid policy documents are:
- **Voluminous**: Thousands of pages across federal and state documents
- **Complex**: Technical language requiring domain expertise
- **Fragmented**: Information spread across multiple documents
- **Dynamic**: Frequent updates and revisions

Traditional search and retrieval methods are insufficient for answering nuanced policy questions.

### Solution Approach
By generating a large-scale QA dataset from policy documents, we can:
- Train models to understand Medicaid policy language
- Enable natural language querying of policy information
- Support policy analysis and compliance checking
- Democratize access to policy knowledge

### Beneficiaries
- **Medicaid Beneficiaries**: Better access to information about their benefits
- **Healthcare Providers**: Quick answers to coverage and billing questions
- **Policy Researchers**: Dataset for analyzing policy trends and variations
- **State Administrators**: Tools for policy analysis and training
- **AI Researchers**: Benchmark dataset for healthcare policy NLP

---

## Dataset Composition

### Instance Structure
Each instance in the dataset represents a single question-answer pair with metadata.

**Example:**
```json
{
  "id": "qa_00001",
  "question": "What are the income eligibility requirements for Medicaid in [State]?",
  "answer": "According to the [State] Medicaid State Plan, individuals with income up to 138% of the Federal Poverty Level (FPL) are eligible for Medicaid coverage. This includes...",
  "source_document": "state_medicaid_plan_2024.pdf",
  "source_page": 15,
  "confidence": 0.95,
  "metadata": {
    "chunk_id": "chunk_042",
    "generation_timestamp": "2025-11-04T10:30:00Z",
    "model": "meta-llama/Llama-3.1-70B-Instruct",
    "question_type": "factual",
    "validation_status": "manual_reviewed"
  }
}
```

### Fields Description

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | string | Unique identifier for QA pair | "qa_00001" |
| `question` | string | Natural language question | "What are the income eligibility requirements..." |
| `answer` | string | Grounded answer from policy documents | "According to the [State] Medicaid State Plan..." |
| `source_document` | string | Source PDF filename | "state_medicaid_plan_2024.pdf" |
| `source_page` | integer | Page number in source document | 15 |
| `confidence` | float | Model confidence score (0-1) | 0.95 |
| `metadata` | object | Additional information | {...} |

### Metadata Fields

- `chunk_id`: Identifier for the text chunk used for generation
- `generation_timestamp`: When the QA pair was generated
- `model`: Model used for generation
- `question_type`: Category (factual, procedural, interpretive, etc.)
- `validation_status`: Quality validation status

---

## Collection Process

### Pipeline Overview
```
Source PDFs → Docling Conversion → Markdown → Augmentoolkit → QA Pairs → Validation → Final Dataset
```

### Step-by-Step Process

#### 1. Source Document Collection
- **Sources**: State Medicaid agencies, CMS (Centers for Medicare & Medicaid Services)
- **Document Types**: State plans, eligibility manuals, provider handbooks, billing guides
- **Collection Period**: [To be filled]
- **Total Documents**: ~1,100 PDFs

#### 2. PDF to Markdown Conversion
- **Tool**: Docling v0.0.14+
- **Process**: Automated conversion with OCR for scanned documents
- **Quality Control**: Manual review of sample conversions
- **Output**: ~1,100 markdown files

#### 3. Text Chunking
- **Chunk Size**: 1,500 characters (configurable)
- **Overlap**: None (sequential chunks)
- **Rationale**: Balance between context and processing efficiency

#### 4. QA Generation
- **Model**: Llama 3.1 70B Instruct via vLLM
- **Framework**: Augmentoolkit v2.x/3.0
- **Configuration**: See `configs/medicaid_config.yaml`
- **Questions per Chunk**: 5 (average)
- **Validation**: Multi-step validation process
  1. Question clarity check
  2. Answer relevancy check
  3. Answer accuracy check
  4. Source grounding verification

#### 5. Quality Filtering
- **Automated Filters**:
  - Remove QA pairs with confidence <0.7
  - Remove duplicates
  - Check for required fields
- **Manual Review**:
  - Sample 100+ QA pairs per batch
  - Multi-reviewer validation
  - Quality scoring (1-5 scale)

---

## Preprocessing and Quality Control

### PDF Preprocessing
1. **Format Standardization**: Convert all PDFs to markdown
2. **OCR**: Apply to scanned documents
3. **Structure Preservation**: Maintain headers, tables, lists
4. **Encoding**: Ensure UTF-8 encoding throughout

### Quality Control Measures

#### Automated Validation
- ✅ JSON schema validation
- ✅ Required field presence check
- ✅ Answer length constraints (50-1000 characters)
- ✅ Source document reference validation
- ✅ Duplicate detection (fuzzy matching)
- ✅ Language detection (English only)

#### Manual Validation
- ✅ Random sampling: 100+ pairs per 1,000 generated
- ✅ Quality dimensions:
  - **Question Clarity** (1-5): Is the question clear and answerable?
  - **Answer Accuracy** (1-5): Is the answer factually correct?
  - **Source Relevance** (1-5): Does the answer properly cite sources?
  - **Overall Quality** (1-5): Would this be useful for training?
- ✅ Inter-annotator agreement: Calculated on subset with multiple reviewers

### Quality Targets
- **Automated Validation Pass Rate**: >95%
- **Manual Review Average Score**: >4.0/5
- **Overall Acceptance Rate**: >85%

---

## Dataset Statistics

### Size Metrics
_To be filled after generation completes_

| Metric | Count |
|--------|-------|
| Total QA Pairs | ~5,500 (target) |
| Training Set | ~4,400 (80%) |
| Validation Set | ~550 (10%) |
| Test Set | ~550 (10%) |
| Source Documents | 1,100 |
| Unique Policies | [TBD] |
| States Covered | [TBD] |

### Text Statistics
_To be filled after generation completes_

| Metric | Average | Median | Min | Max |
|--------|---------|--------|-----|-----|
| Question Length (words) | [TBD] | [TBD] | [TBD] | [TBD] |
| Answer Length (words) | [TBD] | [TBD] | [TBD] | [TBD] |
| Question Length (chars) | [TBD] | [TBD] | [TBD] | [TBD] |
| Answer Length (chars) | [TBD] | [TBD] | [TBD] | [TBD] |

### Topic Distribution
_To be filled after analysis_

| Topic Category | Count | Percentage |
|----------------|-------|------------|
| Eligibility | [TBD] | [TBD]% |
| Benefits/Coverage | [TBD] | [TBD]% |
| Provider Information | [TBD] | [TBD]% |
| Billing/Claims | [TBD] | [TBD]% |
| Appeals/Grievances | [TBD] | [TBD]% |
| Other | [TBD] | [TBD]% |

### Question Types
_To be filled after analysis_

| Question Type | Count | Percentage |
|---------------|-------|------------|
| Factual (Who, What, When) | [TBD] | [TBD]% |
| Procedural (How to...) | [TBD] | [TBD]% |
| Interpretive (What does X mean?) | [TBD] | [TBD]% |
| Comparative (Difference between...) | [TBD] | [TBD]% |
| Other | [TBD] | [TBD]% |

---

## Intended Uses

### Primary Use Cases

#### 1. Fine-Tuning Language Models
Train or fine-tune LLMs to:
- Answer Medicaid policy questions accurately
- Understand healthcare policy terminology
- Ground responses in authoritative sources
- Handle complex multi-step policy queries

**Example Models**: Llama, Mistral, Falcon, domain-specific healthcare models

#### 2. Policy Question Answering Systems
Build applications that:
- Provide instant answers to beneficiary questions
- Support healthcare provider inquiries
- Assist policy researchers in analysis
- Enable compliance checking

#### 3. Retrieval-Augmented Generation (RAG) Evaluation
- Benchmark RAG systems on healthcare policy domain
- Evaluate retrieval quality with known source documents
- Test answer accuracy against ground truth

#### 4. Research and Analysis
- Study state-level policy variations
- Analyze policy language and complexity
- Track policy changes over time
- Identify gaps in policy documentation

### Secondary Use Cases
- **Training Data Augmentation**: Supplement other healthcare QA datasets
- **Policy Summarization**: Generate summaries of policy documents
- **Semantic Search**: Improve policy document search systems
- **Compliance Tools**: Develop policy compliance checking systems

---

## Out-of-Scope Uses

⚠️ **This dataset should NOT be used for:**

### Medical or Clinical Decision Making
- This dataset covers **policy**, not clinical medicine
- Not suitable for diagnosis, treatment recommendations, or medical advice
- Should not replace clinical decision support systems

### Legal Advice
- Policies may change; dataset may become outdated
- Interpretations may vary by jurisdiction
- Not a substitute for legal counsel
- Use only for informational/educational purposes

### Automated Decision Systems Without Human Oversight
- Should not be sole basis for coverage determinations
- Requires human review for high-stakes decisions
- Must be combined with current policy documents

### Commercial Use Without Verification
- Policies may have changed since dataset creation
- Requires validation against current policy versions
- Must comply with source document licensing

### Training General-Purpose Models Without Domain Adaptation
- Dataset is domain-specific (Medicaid policy)
- May not generalize well to other healthcare domains
- Should be combined with broader healthcare knowledge

---

## Dataset Structure

### File Organization
```
medicaid_qa_dataset_v1/
├── train.jsonl          # Training set (80%)
├── val.jsonl            # Validation set (10%)
├── test.jsonl           # Test set (10%)
├── metadata.json        # Dataset-level metadata
├── statistics.json      # Detailed statistics
├── README.txt           # Quick start guide
├── SHA256SUMS           # File checksums
└── docs/
    ├── dataset_card.md  # This file
    └── source_documents_list.txt
```

### Data Format
**Format**: JSONL (JSON Lines) - one JSON object per line  
**Encoding**: UTF-8  
**Line Endings**: Unix-style (LF)

### Loading the Dataset

**Python (with pandas):**
```python
import pandas as pd
import json

# Load training data
with open('train.jsonl', 'r') as f:
    train_data = [json.loads(line) for line in f]
    
df_train = pd.DataFrame(train_data)
print(f"Loaded {len(df_train)} training examples")
```

**Python (with datasets library):**
```python
from datasets import load_dataset

dataset = load_dataset('json', data_files={
    'train': 'train.jsonl',
    'validation': 'val.jsonl',
    'test': 'test.jsonl'
})

print(dataset)
```

**Python (streaming):**
```python
import json

def stream_jsonl(filepath):
    with open(filepath, 'r') as f:
        for line in f:
            yield json.loads(line)

for item in stream_jsonl('train.jsonl'):
    print(item['question'])
```

---

## Data Splits

### Split Strategy
- **Method**: Random shuffle with fixed seed (seed=42)
- **Stratification**: None (simple random split)
- **Rationale**: Ensure diverse coverage across all splits

### Split Sizes
| Split | Percentage | Approximate Size | Purpose |
|-------|------------|------------------|---------|
| Train | 80% | ~4,400 pairs | Model training |
| Validation | 10% | ~550 pairs | Hyperparameter tuning |
| Test | 10% | ~550 pairs | Final evaluation |

### Split Characteristics
- **No overlap**: Each QA pair appears in only one split
- **No leakage**: Source documents may appear across splits (feature, not bug)
- **Balanced**: Splits roughly maintain topic distribution
- **Reproducible**: Fixed seed ensures consistent splits

---

## Source Documents

### Document Sources
- **Federal**: CMS (Centers for Medicare & Medicaid Services)
- **State**: Individual state Medicaid agencies (50 states + DC + territories)
- **Types**: State plans, eligibility manuals, provider handbooks, billing guidelines

### Document Characteristics
- **Publication Dates**: [To be filled with date range]
- **Average Length**: [To be filled]
- **Languages**: English (primary), with some bilingual documents
- **Formats**: PDF (official government documents)

### Geographic Coverage
_To be filled after analysis_

| Region | States | Document Count |
|--------|--------|----------------|
| Northeast | [TBD] | [TBD] |
| Southeast | [TBD] | [TBD] |
| Midwest | [TBD] | [TBD] |
| Southwest | [TBD] | [TBD] |
| West | [TBD] | [TBD] |
| Territories | [TBD] | [TBD] |

### Document Licensing
- **Status**: Public domain (government documents)
- **Restrictions**: [To be verified for each state]
- **Redistribution**: Generally permitted; verify specific terms
- **Attribution**: Recommend citing original source documents

---

## Annotation Process

### Generation Process
- **Type**: Automated generation with manual validation
- **Model**: Llama 3.1 70B Instruct
- **Prompting Strategy**: Multi-turn prompts with validation steps
- **Generation Parameters**:
  - Temperature: [To be filled from config]
  - Top-p: [To be filled from config]
  - Max tokens: [To be filled from config]

### Validation Workflow
1. **Automated Generation**: Augmentoolkit generates initial QA pairs
2. **Automated Validation**: Built-in validation steps check quality
3. **Confidence Scoring**: Each pair assigned confidence score
4. **Manual Sampling**: Random sample reviewed by human validators
5. **Quality Filtering**: Low-quality pairs filtered based on criteria
6. **Final Review**: Spot checks on filtered dataset

### Annotator Information
- **Number of Annotators**: [To be filled]
- **Expertise**: Healthcare policy, data annotation, domain experts
- **Training**: [To be documented]
- **Agreement**: [To be calculated on multi-annotator subset]

---

## Quality Assurance

### Automated Quality Checks
✅ **Structural Validation**
- JSON format correctness
- Required fields present
- Data type compliance

✅ **Content Validation**
- Question ends with '?'
- Answer is non-empty (50-1000 chars)
- Source reference exists
- No placeholder text

✅ **Semantic Validation**
- Answer relevance to question (model-based)
- Answer grounding in source text (similarity check)
- No hallucination markers detected

### Manual Quality Review

**Sample Size**: 100 QA pairs per 1,000 generated

**Review Criteria**:
1. **Question Clarity** (1-5)
   - 5: Crystal clear, unambiguous
   - 4: Clear with minor ambiguity
   - 3: Understandable but could be clearer
   - 2: Somewhat unclear
   - 1: Very unclear or nonsensical

2. **Answer Accuracy** (1-5)
   - 5: Completely accurate, well-cited
   - 4: Accurate with minor issues
   - 3: Mostly accurate
   - 2: Partially accurate
   - 1: Inaccurate or hallucinated

3. **Source Relevance** (1-5)
   - 5: Perfectly relevant, proper citation
   - 4: Relevant with minor citation issues
   - 3: Somewhat relevant
   - 2: Marginally relevant
   - 1: Not relevant

4. **Overall Quality** (1-5)
   - 5: Excellent, ready for training
   - 4: Good, minor improvements possible
   - 3: Acceptable
   - 2: Poor, needs revision
   - 1: Unacceptable

**Acceptance Threshold**: Overall quality ≥3

### Quality Metrics
_To be filled after manual review_

| Metric | Score |
|--------|-------|
| Average Question Clarity | [TBD]/5 |
| Average Answer Accuracy | [TBD]/5 |
| Average Source Relevance | [TBD]/5 |
| Average Overall Quality | [TBD]/5 |
| Acceptance Rate | [TBD]% |
| Inter-Annotator Agreement (Cohen's κ) | [TBD] |

---

## Ethical Considerations

### Privacy and Sensitive Information
- ✅ **No PII**: Source documents are policy documents, not case files
- ✅ **No PHI**: No protected health information included
- ✅ **Public Documents**: All sources are publicly available
- ⚠️ **Verification Needed**: Confirm no inadvertent inclusion of sensitive data

### Fairness and Bias

**Potential Biases**:
1. **Geographic Bias**: Coverage may not be uniform across all states
2. **Temporal Bias**: Policies may reflect specific time period
3. **Language Bias**: English-only, may not capture multilingual policies
4. **Topic Bias**: Some policy areas may be over/under-represented

**Mitigation Strategies**:
- Document coverage by state/region
- Include publication dates in metadata
- Note language limitations
- Analyze and report topic distribution

### Intended Beneficiaries
- **Primary**: Medicaid beneficiaries seeking information
- **Secondary**: Healthcare providers, researchers, administrators
- **Tertiary**: AI/NLP research community

### Potential Harms

**Risk**: Outdated information leading to incorrect decisions
- **Mitigation**: Include timestamps, encourage verification against current policies
- **Severity**: Medium to High

**Risk**: Over-reliance on automated systems without human oversight
- **Mitigation**: Clear documentation of out-of-scope uses
- **Severity**: Medium

**Risk**: Amplification of biases in source documents
- **Mitigation**: Document known biases, encourage critical use
- **Severity**: Low to Medium

---

## Limitations and Biases

### Known Limitations

#### 1. Temporal Limitations
- **Snapshot in Time**: Dataset reflects policies as of [date range]
- **Policy Changes**: Medicaid policies change frequently
- **Expiration Risk**: Information may become outdated quickly

**Recommendation**: Always verify against current policy documents for operational use.

#### 2. Geographic Limitations
- **Coverage Variation**: Not all states equally represented
- **Missing Regions**: Some territories may have limited coverage
- **State-Specific**: Answers may not generalize across states

**Recommendation**: Check metadata for source state before applying answers.

#### 3. Topic Limitations
- **Uneven Coverage**: Some policy areas more represented than others
- **Document Availability**: Limited by available source documents
- **Complexity Variation**: Simple policies may be over-represented

**Recommendation**: Analyze topic distribution before using for specific domains.

#### 4. Language Limitations
- **English Only**: Does not include non-English policy documents
- **Technical Language**: Heavy use of policy/medical jargon
- **Reading Level**: May require high literacy level

**Recommendation**: Post-process for accessibility if targeting general public.

#### 5. Generation Limitations
- **Model Hallucinations**: Despite validation, some errors may remain
- **Synthetic Data**: Not human-written, may lack nuance
- **Confidence Scores**: Imperfect indicators of quality

**Recommendation**: Human review for high-stakes applications.

### Known Biases

#### 1. Source Document Biases
- Policy documents may reflect systemic biases
- Some populations may be underserved in policies
- Administrative language may favor institutional perspectives

#### 2. Model Biases
- Llama 3.1 70B has inherent biases from training
- May favor certain phrasings or interpretations
- Generation prompts may introduce bias

#### 3. Coverage Biases
- States with more comprehensive documentation over-represented
- More recent policies may have better PDF quality
- Complex policies may have lower quality conversions

---

## Distribution and Maintenance

### Distribution

**Hosting**: [To be determined]
- Options: Illinois institutional repository, Hugging Face, GitHub, dedicated server

**Access**: [To be determined]
- Public release (recommended for public documents)
- Restricted access (if source licensing requires)
- Gated access with terms of use

**Format**: Compressed archive (tar.gz) with all splits and documentation

### Versioning

**Current Version**: 1.0  
**Version Scheme**: Semantic versioning (MAJOR.MINOR.PATCH)

**Version History**:
| Version | Date | Changes |
|---------|------|---------|
| 1.0 | [TBD] | Initial release |

### Maintenance Plan

**Lead Maintainer**: Ben Barnard (contact: [email])

**Update Schedule**:
- **Major Updates**: Annually or upon significant policy changes
- **Minor Updates**: Quarterly for bug fixes and quality improvements
- **Patch Updates**: As needed for critical errors

**Planned Updates**:
- Incorporate new policy documents as released
- Expand geographic coverage
- Improve quality based on user feedback
- Add additional metadata fields

### Contact Information

**Questions/Issues**: [To be filled]
- **Email**: [project email]
- **GitHub Issues**: [if applicable]
- **Slack**: #medicaid-qa (internal)

**Data Requests**: [process for requesting access]

**Bug Reports**: [how to report issues in the data]

---

## Citation

### Recommended Citation

**BibTeX**:
```bibtex
@dataset{medicaid_qa_2025,
  author = {Barnard, Ben and [Other Contributors]},
  title = {Medicaid Policy Question-Answer Dataset},
  year = {2025},
  publisher = {University of Illinois at Urbana-Champaign},
  version = {1.0},
  url = {[To be filled]}
}
```

**APA**:
```
Barnard, B., et al. (2025). Medicaid Policy Question-Answer Dataset (Version 1.0) 
[Data set]. University of Illinois at Urbana-Champaign. [URL]
```

**Chicago**:
```
Barnard, Ben, et al. "Medicaid Policy Question-Answer Dataset." University of 
Illinois at Urbana-Champaign, 2025. https://[URL]
```

### Acknowledgments

This dataset was created using:
- **Augmentoolkit**: Framework by E.P. Armstrong
- **Llama 3.1 70B**: Model by Meta AI
- **vLLM**: Efficient inference engine
- **Docling**: PDF processing by [team]
- **UIUC Campus Cluster**: Computing infrastructure

### Funding

**Supported by**: [To be filled if applicable]

---

## Changelog

### Version 1.0 (2025-11-04)
- Initial dataset creation
- ~5,500 QA pairs from 1,100 Medicaid policy documents
- Train/val/test splits created
- Documentation completed

---

**Last Updated**: 2025-11-04  
**Dataset Version**: 1.0  
**Documentation Version**: 1.0

For questions or issues, contact: [project email]
