"""Check the full plan and publish only a sanitized text view and derived facts."""

import argparse
import collections
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_text(path):
    raw = path.read_bytes()
    return raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--terraform", default="terraform")
    parser.add_argument("--plan", default=".private/full.tfplan")
    parser.add_argument("--text", type=Path, default=Path(".private/full-plan.txt"))
    args = parser.parse_args()
    result = subprocess.run([args.terraform, "show", "-json", args.plan], cwd=ROOT, check=True, capture_output=True, text=True)
    plan = json.loads(result.stdout)
    managed = [resource for resource in plan["resource_changes"] if resource["mode"] == "managed"]
    if not all(resource["change"]["actions"] == ["create"] for resource in managed):
        raise ValueError("Expected an initial create-only plan; review the changed actions before publishing")
    resources = {resource["address"]: resource["change"]["after"] for resource in managed}
    db = resources["module.database.aws_db_instance.this"]
    fleet = resources["module.compute.aws_autoscaling_group.wordpress"]
    distribution = resources["module.cdn.aws_cloudfront_distribution.this"]
    config = plan["configuration"]
    certs = config["root_module"]["module_calls"]["certificates"]["module"]["resources"]
    checks = {
        "private_encrypted_multi_az_rds": not db["publicly_accessible"] and db["storage_encrypted"] and db["multi_az"],
        "rds_managed_password_no_password_literal": db["manage_master_user_password"] and db.get("password") is None,
        "asg_bounds_and_elb_health": fleet["min_size"] == 1 and fleet["max_size"] == 4 and fleet["health_check_type"] == "ELB",
        "origin_certificate_name_match": resources["module.certificates.aws_acm_certificate.origin"]["domain_name"] == distribution["origin"][0]["domain_name"],
        "viewer_certificate_us_east_1": config["provider_config"]["aws.us_east_1"]["expressions"]["region"]["constant_value"] == "us-east-1" and any(resource["name"] == "viewer" and resource["provider_config_key"] == "aws.us_east_1" for resource in certs if resource["type"] == "aws_acm_certificate"),
        "asg_attached_to_alb": "module.load_balancer.target_group_arn" in config["root_module"]["module_calls"]["compute"]["expressions"]["target_group_arns"]["references"],
        "origin_https_only": distribution["origin"][0]["custom_origin_config"][0]["origin_protocol_policy"] == "https-only",
        "dynamic_cache_disabled": resources["module.cdn.aws_cloudfront_cache_policy.dynamic"]["max_ttl"] == 0,
        "no_error_response_cache": all(error["error_caching_min_ttl"] == 0 for error in distribution["custom_error_response"]),
    }
    if not all(checks.values()):
        raise ValueError("Full-plan check failed: " + ", ".join(key for key, value in checks.items() if not value))
    evidence = ROOT / "evidence"
    evidence.mkdir(exist_ok=True)
    summary = {
        "scope": "Full architecture, real AWS-backed Terraform plan; example DNS inputs; no apply",
        "add": len(managed), "change": 0, "destroy": 0,
        "resources_by_type": dict(sorted(collections.Counter(resource["type"] for resource in managed).items())),
        "checks": checks,
        "domain_limitation": "school.example.com and origin.example.com are unowned placeholders. DNS validation and runtime TLS have not run.",
    }
    (evidence / "plan-summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    text = read_text(ROOT / args.text)
    # Terraform's text view honors sensitive flags. Also remove known sensitive
    # string values from JSON, if a later plan ever contains such values.
    sensitive = set()
    def collect(value, mask):
        if mask is True:
            if isinstance(value, str) and len(value) >= 8:
                sensitive.add(value)
            elif isinstance(value, (list, dict)):
                for item in value.values() if isinstance(value, dict) else value:
                    collect(item, True)
        elif isinstance(mask, dict) and isinstance(value, dict):
            for key, nested in mask.items():
                collect(value.get(key), nested)
        elif isinstance(mask, list) and isinstance(value, list):
            for item, nested in zip(value, mask):
                collect(item, nested)
    for resource in managed:
        collect(resource["change"].get("after"), resource["change"].get("after_sensitive", {}))
    for value in sorted(sensitive, key=len, reverse=True):
        text = text.replace(value, "[REDACTED-SENSITIVE]")
    text = re.sub(r"\b\d{12}\b", "[AWS-ACCOUNT-ID]", text)
    text = text.replace(str(ROOT), "[WORKSPACE]").replace(ROOT.as_posix(), "[WORKSPACE]")
    text = text.replace(".private/full.tfplan", "[PRIVATE-SAVED-PLAN]").replace(".private\\full.tfplan", "[PRIVATE-SAVED-PLAN]")
    preface = "SANITIZED REAL TERRAFORM PLAN — NOT A DEPLOYMENT RESULT\nExample DNS names are placeholders. No certificate has been issued or runtime HTTPS tested.\nAccount IDs, workspace paths and any marked sensitive values are redacted.\n\n"
    (evidence / "terraform-plan.txt").write_text(preface + text, encoding="utf-8")
    paths = [*ROOT.glob("*.tf"), *ROOT.glob(".terraform.lock.hcl"), *ROOT.glob("modules/**/*.tf"), *ROOT.glob("modules/**/*.py"), *ROOT.glob("modules/**/*.sh"), *ROOT.glob("modules/**/*.tftpl"), *ROOT.glob("modules/**/*.php"), *ROOT.glob("assets/*.json")]
    hashes = {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(set(paths))}
    (evidence / "configuration-sha256.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")
    print(f"Full plan: {len(managed)} create-only resources; {len(checks)} configuration checks passed; sanitized evidence written.")


if __name__ == "__main__":
    main()
