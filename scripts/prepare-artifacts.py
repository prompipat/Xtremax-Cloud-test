"""Build the portable Lambda ZIP from locked, verified upstream downloads."""

import hashlib
import io
import json
import ssl
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def download(entry):
    cache = ROOT / ".private/artifact-cache" / entry["sha256"]
    if cache.exists():
        payload = cache.read_bytes()
        if hashlib.sha256(payload).hexdigest() == entry["sha256"]:
            return payload
    with urllib.request.urlopen(entry["url"], timeout=60) as response:
        payload = response.read()
    if hashlib.sha256(payload).hexdigest() != entry["sha256"]:
        raise ValueError("Download checksum mismatch: " + entry["url"])
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_bytes(payload)
    return payload


def main():
    manifest = json.loads((ROOT / "assets/downloads.json").read_text(encoding="utf-8"))
    wheel = download(manifest["pymysql"])
    ca_bundle = download(manifest["rds_ca"])
    ssl.create_default_context(cadata=ca_bundle.decode("ascii"))
    files = {
        "handler.py": (ROOT / "modules/initialization/lambda/handler.py").read_bytes(),
        "global-bundle.pem": ca_bundle,
    }
    with zipfile.ZipFile(io.BytesIO(wheel)) as archive:
        for name in archive.namelist():
            if name.startswith(("pymysql/", "pymysql-")) and not name.endswith("/"):
                files[name] = archive.read(name)
    output = ROOT / "artifacts/db-initializer.zip"
    output.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, content in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, content)
    print("Built artifacts/db-initializer.zip (SHA256 " + hashlib.sha256(output.read_bytes()).hexdigest() + ")")


if __name__ == "__main__":
    main()
