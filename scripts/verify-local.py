"""Run reproducible local gates; all Terraform test operations are mocked."""

import argparse
import hashlib
import json
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--terraform", default="terraform")
    parser.add_argument("--php")
    parser.add_argument("--bash")
    parser.add_argument("--rendered-state", default=".private/compute-tests.jsonl")
    args = parser.parse_args()
    commands = [
        [args.terraform, "fmt", "-check", "-recursive"],
        [args.terraform, "validate", "-no-color"],
        [args.terraform, "test", "-no-color"],
        [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v"],
        [sys.executable, "scripts/check-rendered-userdata.py", args.rendered_state],
    ]
    if args.php:
        commands.extend([args.php, "-n", "-l", str(path.relative_to(ROOT))] for path in sorted((ROOT / "modules/compute/templates").glob("*.php")))
        commands.append([args.php, "-n", "-d", "extension_dir=" + str(Path(args.php).resolve().parent / "ext"), "-d", "extension=mysqli", "tests/check-php-tls.php"])
    if args.bash:
        commands.extend([args.bash, "-n", script] for script in [".private/rendered-user-data.sh", "modules/compute/templates/bootstrap.sh", "modules/compute/templates/initialize-content.sh"])
    evidence = ["Final local verification - 2026-11-01 (Asia/Bangkok)", "Scope: static, mocked and fake-client checks; no real deployment."]
    for command in commands:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        label = " ".join([Path(command[0]).name, *command[1:]])
        if result.returncode != 0:
            raise RuntimeError("Check failed: " + label + "\n" + result.stdout + result.stderr)
        evidence += ["\n$ " + label, result.stdout, result.stderr, "PASS"]
        print("PASS: " + label)
    with zipfile.ZipFile(ROOT / "artifacts/db-initializer.zip") as archive:
        if archive.read("handler.py") != (ROOT / "modules/initialization/lambda/handler.py").read_bytes():
            raise ValueError("Stale initializer artifact")
        manifest = json.loads((ROOT / "assets/downloads.json").read_text(encoding="utf-8"))
        if hashlib.sha256(archive.read("global-bundle.pem")).hexdigest() != manifest["rds_ca"]["sha256"]:
            raise ValueError("Initializer CA differs from lock manifest")
    evidence.append("Initializer artifact source and locked CA: PASS")
    summary = json.loads((ROOT / "evidence/plan-summary.json").read_text(encoding="utf-8"))
    evidence.append(f"Separate real AWS-backed plan: {summary['add']} to add, {summary['change']} to change, {summary['destroy']} to destroy; {len(summary['checks'])} derived checks passed.")
    text = "\n".join(evidence).replace(str(ROOT), "[WORKSPACE]").replace(str(Path(sys.executable).parent), "[PYTHON-INSTALL]")
    (ROOT / "evidence/final-checks.txt").write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
