"""Render the English Markdown report to local HTML and optionally PDF via Edge."""

import argparse
import importlib.metadata
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tools/report-deps"))


def main():
    import markdown

    parser = argparse.ArgumentParser()
    parser.add_argument("--browser", help="Path to Edge/Chromium executable for headless PDF printing")
    args = parser.parse_args()
    source = (ROOT / "docs/report.md").read_text(encoding="utf-8")
    body = markdown.markdown(source, extensions=["tables", "fenced_code", "toc", "sane_lists"])
    css = """
    @page {size:A4; margin:16mm 15mm 17mm}
    * {box-sizing:border-box}
    body {font:10.5pt/1.48 'Segoe UI',Arial,sans-serif; color:#203249; margin:0}
    h1 {font-size:25pt; line-height:1.16; color:#153a62; margin:0 0 8mm}
    h2 {font-size:17pt; color:#234969; margin:5mm 0}
    h3 {font-size:13pt; color:#234969; margin:7mm 0 3mm; break-after:avoid}
    p {margin:0 0 3.3mm; orphans:3; widows:3}
    a {color:#185b87; text-decoration:none; overflow-wrap:anywhere}
    table {width:100%; border-collapse:collapse; font-size:8.8pt; line-height:1.34; margin:3mm 0 5mm; table-layout:fixed}
    thead {display:table-header-group}
    tr {break-inside:avoid}
    th {background:#e9f0f7; color:#183c5e; text-align:left}
    td,th {border:1px solid #cdd8e5; padding:2mm; vertical-align:top; overflow-wrap:anywhere}
    table tr:nth-child(even) td {background:#f8fafc}
    img {display:block; width:100%; height:auto; max-height:220mm; object-fit:contain; margin:3mm 0 5mm; break-inside:avoid}
    code {font:8.8pt Consolas,monospace; background:#f0f4f8; overflow-wrap:anywhere}
    pre {white-space:pre-wrap; overflow-wrap:anywhere; padding:3mm; border:1px solid #d1dbe6; break-inside:avoid}
    ul {padding-left:5mm; margin:2mm 0 4mm}
    li {margin-bottom:1.5mm; overflow-wrap:anywhere}
    """
    output = ROOT / "docs/report.html"
    output.write_text('<!doctype html><html lang="en"><meta charset="utf-8"><title>Xtremax Cloud Engineer Technical Report</title><style>' + css + '</style><body>' + body + '</body></html>', encoding="utf-8")
    print("Generated docs/report.html with Markdown " + importlib.metadata.version("Markdown"))
    if args.browser:
        profile = ROOT / ".private/report-browser"
        profile.mkdir(parents=True, exist_ok=True)
        subprocess.run([
            args.browser, "--headless", "--disable-gpu", "--disable-extensions", "--no-first-run",
            "--no-pdf-header-footer", "--allow-file-access-from-files",
            "--user-data-dir=" + str(profile), "--print-to-pdf=" + str(ROOT / "docs/report.pdf"), output.as_uri(),
        ], check=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
        if not (ROOT / "docs/report.pdf").exists():
            raise RuntimeError("Browser did not generate report.pdf")
        print("Generated docs/report.pdf")


if __name__ == "__main__":
    main()
