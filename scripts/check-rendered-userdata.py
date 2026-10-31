"""Check EC2 payload size and extract the real Terraform-rendered shell for linting."""

import argparse
import base64
import gzip
import json
import re
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("test_json", type=Path)
    parser.add_argument("--output", type=Path, default=Path(".private/rendered-user-data.sh"))
    args = parser.parse_args()
    payload = args.test_json.read_bytes()
    content = payload.decode("utf-16" if payload.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")
    entries = [json.loads(line) for line in content.splitlines() if line.strip()]
    state = next(entry["test_state"] for entry in entries if entry.get("type") == "test_state")
    template = next(resource["values"] for resource in state["root_module"]["resources"] if resource["type"] == "aws_launch_template")
    compressed = base64.b64decode(template["user_data"], validate=True)
    if len(compressed) > 16384:
        raise ValueError("Compressed EC2 user data exceeds 16 KiB")
    rendered = gzip.decompress(compressed).decode("utf-8")
    if not rendered.startswith("#!/bin/bash\n") or "${config_b64}" in rendered:
        raise ValueError("Invalid or unrendered bootstrap shell")
    match = re.search(r"printf '%s' '([^']+)' \| base64 -d > /opt/xtremax/config.json", rendered)
    settings = json.loads(base64.b64decode(match.group(1)))
    if any(key in settings for key in ["password", "master_secret_arn", "admin_password"]):
        raise ValueError("Credentials or master secret pointer found in EC2 bootstrap settings")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8", newline="\n")
    print(f"Rendered user data: PASS ({len(compressed)} compressed bytes; no credential values in settings)")


if __name__ == "__main__":
    main()
