"""Generate readable module input/output indexes from the source declarations."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PURPOSE = {
    "network": "Creates the two-AZ VPC, six subnets, NAT/internet routing and tier NACLs.",
    "security": "Creates dedicated ALB, application, database and EFS security groups and stateful traffic rules.",
    "database": "Creates private encrypted RDS MySQL with managed master credentials, backups and TLS enforcement.",
    "storage": "Creates encrypted Regional EFS with two mount targets, a WordPress access point and policy guardrails.",
    "initialization": "Creates a dedicated private Lambda initializer and application-secret metadata; invokes initialization at apply only.",
    "compute": "Creates the restricted EC2 role/profile, WordPress launch template, ASG, CPU alarms and step-scaling policies.",
    "certificates": "Requests and validates separate origin and viewer ACM certificates, with optional Route 53 validation records.",
    "load_balancer": "Creates the public HTTPS ALB, default-deny listener, private-header forwarding rule and instance target group.",
    "cdn": "Creates the custom-domain HTTPS CloudFront distribution and safe WordPress cache/response-header policies.",
}


def declarations(path, kind):
    text = path.read_text(encoding="utf-8")
    matches = list(re.finditer(r'\b' + kind + r'\s+"([^"]+)"\s*\{', text))
    result = []
    for index, match in enumerate(matches):
        segment = text[match.end():matches[index + 1].start() if index + 1 < len(matches) else len(text)]
        description = re.search(r'description\s*=\s*"([^"\n]*)"', segment)
        result.append((match.group(1), description.group(1) if description else "See source declaration."))
    return result


def main():
    for name, purpose in PURPOSE.items():
        directory = ROOT / "modules" / name
        lines = [f"# {name}", "", purpose, "", "Inherits the root AWS provider and project tags. This module's mocked tests do not create AWS resources.", ""]
        if name == "certificates":
            lines += ["Requires the `aws.us_east_1` provider alias for the viewer certificate; the default provider creates the origin certificate.", ""]
        for heading, filename, kind in [("Inputs", "variables.tf", "variable"), ("Outputs", "outputs.tf", "output")]:
            lines += [f"## {heading}", "", "| Name | Description |", "|---|---|"]
            lines += [f"| `{key}` | {description.replace('|', '/')} |" for key, description in declarations(directory / filename, kind)]
            lines += [""]
        lines += ["See `variables.tf` for exact types, defaults and validation. The complete architecture, dependencies and limitations are in the root `docs/report.md` and `docs/report.pdf`.", ""]
        (directory / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print("Generated input/output README files for nine modules.")


if __name__ == "__main__":
    main()
