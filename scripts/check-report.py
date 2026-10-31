"""Validate report text and render representative pages for visual inspection."""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tools/report-deps"))


def main():
    import pypdfium2 as pdfium

    document = pdfium.PdfDocument(ROOT / "docs/report.pdf")
    pages = []
    complete_text = ""
    for index in range(len(document)):
        page = document[index]
        text = page.get_textpage().get_text_range()
        if len(text.strip()) < 100:
            raise ValueError(f"Report page {index + 1} is unexpectedly empty")
        pages.append({"page": index + 1, "text_characters": len(text)})
        complete_text += text
    required = ["108", "NOT RUN", "school.example.com", "origin.example.com", "us-east-1", "min", "30-minute", "Module", "108 additions"]
    if not all(fragment.lower() in complete_text.lower() for fragment in required):
        raise ValueError("A required report statement is missing")
    output = ROOT / ".private/report-qa"
    output.mkdir(parents=True, exist_ok=True)
    for index in [2, 3, len(document) - 1]:
        document[index].render(scale=1.5).to_pil().save(output / f"page-{index + 1}.png")
    (ROOT / "evidence/report-checks.json").write_text(json.dumps({"pages": pages, "required_statements_present": True, "visual_review_pages": [3, 4, len(document)]}, indent=2) + "\n", encoding="utf-8")
    print(f"Report content checks: PASS ({len(document)} nonempty pages); QA images rendered.")


if __name__ == "__main__":
    main()
