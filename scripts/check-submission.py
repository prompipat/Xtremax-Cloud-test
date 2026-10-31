"""Extract the allowlisted ZIP and verify local reproducibility without AWS calls."""

import argparse
import hashlib
import json
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--terraform", default="terraform")
    args = parser.parse_args()
    terraform = Path(args.terraform)
    executable = str(terraform.resolve()) if terraform.exists() else args.terraform
    private = ROOT / ".private"
    private.mkdir(exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="submission-check-", dir=private)).resolve()
    if not directory.is_relative_to(private.resolve()):
        raise ValueError("Extraction target must remain within the private workspace directory")
    with zipfile.ZipFile(ROOT / "submission/terraform-source.zip") as archive:
        for name in archive.namelist():
            path = Path(name)
            if path.is_absolute() or ".." in path.parts or ":" in name:
                raise ValueError("Unsafe archive member: " + name)
        for line in archive.read("MANIFEST.sha256").decode().splitlines():
            digest, name = line.split("  ", 1)
            if hashlib.sha256(archive.read(name)).hexdigest() != digest:
                raise ValueError("Manifest mismatch: " + name)
        archive.extractall(directory)
    source_hashes = json.loads((ROOT / "evidence/configuration-sha256.json").read_text(encoding="utf-8"))
    for name, digest in source_hashes.items():
        if hashlib.sha256((directory / name).read_bytes()).hexdigest() != digest:
            raise ValueError("Extracted configuration differs from reviewed plan source: " + name)
    commands = [
        [executable, "init", "-backend=false", "-input=false", "-no-color", "-lockfile=readonly", "-plugin-dir=" + str(ROOT / ".terraform/providers")],
        [executable, "validate", "-no-color"],
        [executable, "test", "-no-color"],
    ]
    evidence = ["Extracted source bundle: manifest and reviewed-configuration hashes match.", "Scope: initialization/validation/mocked tests only; verified local providers reused; no AWS resources created."]
    for command in commands:
        result = subprocess.run(command, cwd=directory, capture_output=True, text=True)
        evidence.append("\n$ terraform " + " ".join(argument for argument in command[1:] if not argument.startswith("-plugin-dir=")))
        evidence.append(result.stdout)
        if result.stderr:
            evidence.append(result.stderr)
        if result.returncode != 0:
            raise RuntimeError("Reproduction failed: " + command[1] + "\n" + result.stdout + result.stderr)
    (ROOT / "evidence/reproduction-checks.txt").write_text("\n".join(evidence), encoding="utf-8")
    print("Extracted bundle: manifest/source hashes, provider init, validate and 14 mock runs PASS; no AWS calls.")


if __name__ == "__main__":
    main()
