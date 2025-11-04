"""Utility script to convert Medicaid policy PDFs to Markdown via Docling.

Usage:
    python scripts/preprocessing/convert_pdfs.py \
        --input-dir data/raw/sample \
        --output-dir data/processed/sample_markdown \
        --limit 20

Requirements:
    - Docling (pip install docling)
    - pdfminer.six, pypdf for fallbacks (see requirements.txt)

Notes:
    - Conversion parameters should align with Phase 1 Task 1.2.
    - Update LOG_DIR to match data governance policies.
"""

from __future__ import annotations

import argparse
import logging
import pathlib
from typing import Iterable

try:
    from docling.document_converter import DocumentConverter
    from docling.datamodel import ConversionResult
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "Docling is required. Install dependencies with `pip install -r requirements.txt`."
    ) from exc


LOG_DIR = pathlib.Path("data/processed/logs")


def iter_pdfs(input_dir: pathlib.Path, limit: int | None = None) -> Iterable[pathlib.Path]:
    files = sorted(p for p in input_dir.glob("**/*.pdf") if p.is_file())
    if limit is not None:
        files = files[:limit]
    for pdf in files:
        yield pdf


def convert_pdf(converter: DocumentConverter, pdf_path: pathlib.Path, output_dir: pathlib.Path) -> ConversionResult:
    logging.info("Converting %s", pdf_path)
    markdown_path = output_dir / f"{pdf_path.stem}.md"
    markdown_path.parent.mkdir(parents=True, exist_ok=True)
    result = converter.convert(pdf_path)
    markdown_path.write_text(result.document.export_to_markdown(), encoding="utf-8")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert PDFs to Markdown using Docling")
    parser.add_argument("--input-dir", type=pathlib.Path, required=True)
    parser.add_argument("--output-dir", type=pathlib.Path, required=True)
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    LOG_DIR.mkdir(parents=True, exist_ok=True)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(LOG_DIR / "pdf_conversion.log", encoding="utf-8"),
        ],
    )

    if not args.input_dir.exists():
        raise SystemExit(f"Input directory not found: {args.input_dir}")

    converter = DocumentConverter()

    for index, pdf_path in enumerate(iter_pdfs(args.input_dir, args.limit), start=1):
        try:
            result = convert_pdf(converter, pdf_path, args.output_dir)
            logging.info(
                "[%s] Converted %s (pages=%s)",
                index,
                pdf_path.name,
                result.document.page_count,
            )
        except Exception:  # pragma: no cover - operational logging only
            logging.exception("Failed to convert %s", pdf_path)

    logging.info("Conversion complete. Outputs written to %s", args.output_dir)


if __name__ == "__main__":
    main()
