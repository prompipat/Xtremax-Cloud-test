"""Retrieve only the application secret, storing it outside the document root."""

import grp
import json
import os
import subprocess
from pathlib import Path


def main():
    config = json.loads(Path("/opt/xtremax/config.json").read_text())
    response = subprocess.run(
        ["aws", "secretsmanager", "get-secret-value", "--secret-id", config["application_secret_arn"],
         "--region", config["region"], "--query", "SecretString", "--output", "text"],
        check=True, capture_output=True, text=True,
    )
    application = json.loads(response.stdout)
    if application.get("username") != "wordpress":
        raise ValueError("Application credentials are not initialized")
    folder = Path("/etc/wordpress")
    folder.mkdir(mode=0o750, exist_ok=True)
    os.chown(folder, 0, grp.getgrnam("apache").gr_gid)
    temporary = folder / "credentials.json.tmp"
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w") as target:
        json.dump(application, target)
    os.chown(temporary, 0, grp.getgrnam("apache").gr_gid)
    os.chmod(temporary, 0o640)
    temporary.replace(folder / "credentials.json")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        raise SystemExit("Application secret retrieval failed; bootstrap will retry") from None
