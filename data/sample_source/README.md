# Sample Data

This directory contains 2-3 small sample Medicaid policy documents for testing the pipeline.

These are public-domain or synthetic examples used to validate the workflow before processing the full 1,100 PDF dataset.

## Usage

These samples are used in the Quick Start guide to demonstrate the complete pipeline from PDF to QA pairs.

## Getting Started

1. Place 2-3 small test PDFs in this directory (we recommend documents under 10 pages for quick testing)
2. Follow the Quick Start guide in the main README.md
3. The pipeline will convert these PDFs to markdown and generate QA pairs

## Example

```bash
# Place your test PDFs here
data/sample_source/
├── README.md (this file)
├── sample_policy_1.pdf
├── sample_policy_2.pdf
└── sample_policy_3.pdf
```

⚠️ **Note**: We cannot commit PDF files to git due to their size. You'll need to add your own test PDFs to this directory.
