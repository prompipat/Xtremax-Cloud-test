"""Create an allowlisted source bundle and audit its contents before publishing locally."""

import hashlib
import json
import re
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROOT_FILES = ["README.md", ".gitignore", ".terraform.lock.hcl", "versions.tf", "providers.tf", "variables.tf", "main.tf", "outputs.tf", "terraform.tfvars.example", "requirements-report.txt"]
FOLDERS = ["modules", "scripts", "tests", "assets", "docs", "evidence"]
EXTENSIONS = {".tf", ".hcl", ".tftpl", ".py", ".sh", ".php", ".md", ".json", ".txt", ".svg", ".mmd", ".pdf", ".html"}
FORBIDDEN_COMPONENTS = {".git", ".terraform", ".private", ".tools", "__pycache__", ".aws"}


def main():
    candidates = [ROOT / name for name in ROOT_FILES]
    for folder in FOLDERS:
        candidates.extend(path for path in (ROOT / folder).rglob("*") if path.is_file() and path.suffix in EXTENSIONS and not FORBIDDEN_COMPONENTS.intersection(path.relative_to(ROOT).parts))
    candidates.append(ROOT / "artifacts/db-initializer.zip")
    for required in ["docs/report.pdf", "docs/architecture.svg", "docs/module-structure.svg", "docs/test-plan.md", "docs/test-results.md", "evidence/terraform-plan.txt", "evidence/final-checks.txt", "artifacts/db-initializer.zip"]:
        if not (ROOT / required).is_file():
            raise ValueError("Required deliverable missing: " + required)
    files = {}
    for path in sorted(set(candidates)):
        relative = path.relative_to(ROOT).as_posix()
        if path.is_symlink() or FORBIDDEN_COMPONENTS.intersection(path.relative_to(ROOT).parts):
            raise ValueError("Unexpected symlink/private path: " + relative)
        if relative.endswith((".tfstate", ".tfplan", ".pyc")) or (relative.endswith(".tfvars") and relative != "terraform.tfvars.example"):
            raise ValueError("Private Terraform data in source bundle: " + relative)
        payload = path.read_bytes()
        if path.suffix not in {".zip", ".pdf"}:
            content = payload.decode("utf-16" if payload.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")
            if re.search(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----", content):
                raise ValueError("Possible credential/private key in " + relative)
        files[relative] = payload
    manifest = "\n".join(hashlib.sha256(payload).hexdigest() + "  " + name for name, payload in sorted(files.items())) + "\n"
    files["MANIFEST.sha256"] = manifest.encode("utf-8")
    destination = ROOT / "submission"
    destination.mkdir(exist_ok=True)
    archive_path = destination / "terraform-source.zip"
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, payload in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, payload)
    with zipfile.ZipFile(archive_path) as archive:
        if archive.testzip() is not None:
            raise ValueError("Source ZIP CRC failure")
        for line in archive.read("MANIFEST.sha256").decode().splitlines():
            expected, name = line.split("  ", 1)
            if hashlib.sha256(archive.read(name)).hexdigest() != expected:
                raise ValueError("Source ZIP manifest mismatch: " + name)
    for name in ["report.pdf", "architecture.svg", "module-structure.svg", "submission-email.txt"]:
        shutil.copyfile(ROOT / "docs" / name, destination / name)
    checksums = "\n".join(hashlib.sha256(path.read_bytes()).hexdigest() + "  " + path.name for path in sorted(destination.iterdir()) if path.is_file() and path.name in ["terraform-source.zip", "report.pdf", "architecture.svg", "module-structure.svg", "submission-email.txt"]) + "\n"
    (destination / "SHA256SUMS.txt").write_text(checksums, encoding="utf-8")
    (destination / "README.txt").write_text(
        "Prepared locally; no email has been sent.\nSend terraform-source.zip and report.pdf in one email. The ZIP already includes the report, diagrams, tests and sanitized evidence.\nExample domain names are plan-only placeholders; runtime tests are NOT RUN.\nReview submission-email.txt and replace applicant details before sending.\n",
        encoding="utf-8",
    )
    print(f"Source bundle: {len(files)} files, {archive_path.stat().st_size:,} bytes; manifest/CRC/exclusion/credential-pattern checks passed.")


if __name__ == "__main__":
    main()
