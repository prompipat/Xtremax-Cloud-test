"""Generate standalone SVG diagrams without remote rendering services."""

from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def canvas(width, height, title):
    return [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-label="{escape(title)}">',
            '<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#52657b"/></marker></defs>',
            f'<rect width="{width}" height="{height}" fill="#ffffff"/>',
            '<style>text{font-family:Arial,sans-serif;fill:#17283c}.title{font-size:25px;font-weight:700}.label{font-size:16px;font-weight:700}.body{font-size:14px}.note{font-size:13px;fill:#52657b}.edge{fill:none;stroke:#52657b;stroke-width:2;marker-end:url(#arrow)}</style>']


def text(svg, x, y, lines, css="body", anchor="middle", step=22):
    for index, line in enumerate(lines):
        svg.append(f'<text x="{x}" y="{y + index * step}" class="{css}" text-anchor="{anchor}">{escape(line)}</text>')


def box(svg, x, y, width, height, lines, fill="#eef4ff", stroke="#a4bbda"):
    svg.append(f'<rect x="{x}" y="{y}" width="{width}" height="{height}" rx="10" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
    text(svg, x + width / 2, y + 28, lines[:1], "label")
    text(svg, x + width / 2, y + 52, lines[1:])


def edge(svg, path, label=None, x=0, y=0):
    svg.append(f'<path d="{path}" class="edge"/>')
    if label:
        text(svg, x, y, [label], "note")


def architecture():
    svg = canvas(1280, 1100, "Planned WordPress system architecture")
    text(svg, 40, 35, ["WordPress on AWS — planned system architecture"], "title", "start")
    text(svg, 40, 60, ["Plan-only evidence • ap-southeast-2 • No resources deployed • Example DNS names are placeholders"], "note", "start")
    box(svg, 470, 90, 340, 65, ["Website users", "https://school.example.com"], "#f4f7fb")
    box(svg, 470, 200, 340, 85, ["CloudFront", "Viewer TLS ≥ 1.2; dynamic cache disabled", "Cache selected public upload images"])
    edge(svg, "M640 155 L640 200", "HTTPS", 690, 183)
    box(svg, 900, 90, 330, 80, ["ACM and public DNS", "Viewer certificate: us-east-1", "Origin certificate: ap-southeast-2"], "#fff6e7", "#dbbd85")
    text(svg, 1065, 196, ["External DNS or existing public Route 53 zone", "Both names require DNS ownership"], "note")
    svg.append('<rect x="30" y="310" width="1220" height="620" rx="14" fill="#fafcff" stroke="#7895b6" stroke-width="2"/>')
    text(svg, 55, 339, ["VPC 10.20.0.0/16 — three subnet tiers"], "label", "start")
    box(svg, 470, 355, 340, 90, ["Public HTTPS ALB", "Origin: origin.example.com", "Private header required; otherwise 403"], "#eaf6f2", "#8dbbad")
    edge(svg, "M640 285 L640 355", "HTTPS 443 + origin header", 810, 300)
    for x, zone, cidrs in [(60, "ap-southeast-2a", ["0", "2", "4"]), (670, "ap-southeast-2b", ["1", "3", "5"])]:
        svg.append(f'<rect x="{x}" y="450" width="550" height="440" rx="10" fill="#ffffff" stroke="#bbcbdc" stroke-dasharray="7 4"/>')
        text(svg, x + 275, 478, [zone], "label")
        box(svg, x + 20, 500, 510, 75, [f"Public subnet 10.20.{cidrs[0]}.0/24", "ALB node + zonal NAT gateway"], "#eef8f3", "#a6cdb8")
        box(svg, x + 20, 625, 510, 95, [f"Application subnet 10.20.{cidrs[1]}.0/24", "Private WordPress EC2 + EFS mount target", "ASG: min 1 / initial 2 / max 4 across both AZs"], "#eef4ff")
        box(svg, x + 20, 790, 510, 75, [f"Database subnet 10.20.{cidrs[2]}.0/24", "Private RDS Multi-AZ placement; AWS chooses primary"], "#fff6e7", "#dbbd85")
        center = x + 275
        edge(svg, f"M{center} 575 L{center} 625", "ALB → EC2: HTTP 80", center + 120, 606)
        edge(svg, f"M{center} 720 L{center} 790", "MySQL 3306 + TLS", center + 120, 764)
    edge(svg, "M520 445 L335 500")
    edge(svg, "M760 445 L945 500")
    box(svg, 440, 975, 400, 85, ["Regional EFS: shared wp-content", "At-rest encryption; TLS + IAM access point", "NFS lock serializes content/schema installation"], "#f0edfb", "#baacdb")
    edge(svg, "M80 672 L45 672 L45 1015 L440 1015")
    edge(svg, "M1200 672 L1235 672 L1235 1015 L840 1015")
    text(svg, 640, 953, ["NAT/IGW: application HTTPS egress only • DB has no internet default route • SGs + stateless tier NACLs"], "note")
    text(svg, 240, 1045, ["EFS: 2049 + TLS"], "note")
    text(svg, 1040, 1045, ["EFS: 2049 + TLS"], "note")
    svg.append('</svg>')
    return "\n".join(svg)


def modules():
    svg = canvas(1040, 840, "Terraform root and module structure")
    svg.append('<style>.label{font-size:19px}.body{font-size:16px}</style>')
    text(svg, 30, 35, ["Terraform module structure"], "title", "start")
    box(svg, 300, 65, 460, 85, ["Root configuration", "Provider aliases, variables, outputs, DNS records", "Random origin header + nine local modules"], "#eaf6f2", "#8dbbad")
    entries = [
        ("network", ["VPC / subnet tiers", "NAT / routes / NACLs"]),
        ("security", ["Workload SGs", "Tier traffic rules"]),
        ("database", ["RDS MySQL", "TLS / backups"]),
        ("storage", ["EFS / mount targets", "Access point / policy"]),
        ("initialization", ["Private Lambda", "Scoped DB account"]),
        ("compute", ["Role / LT / ASG", "Bootstrap / scaling"]),
        ("certificates", ["Origin + viewer ACM", "DNS validation"]),
        ("load_balancer", ["HTTPS ALB", "Header gate / TG"]),
        ("cdn", ["CloudFront", "Cache / HTTPS"]),
    ]
    svg.append('<path d="M530 150 L530 200 M40 200 L720 200 M40 200 L40 650 M380 200 L380 650 M720 200 L720 650" fill="none" stroke="#52657b" stroke-width="2"/>')
    for index, (name, details) in enumerate(entries):
        x = 60 + (index // 3) * 340
        y = 245 + (index % 3) * 170
        edge(svg, f"M{x - 20} {y + 60} L{x} {y + 60}")
        box(svg, x, y, 260, 120, [name, *details])
    text(svg, 520, 755, ["Each module: main.tf • variables.tf • outputs.tf • versions.tf • README.md", "Root DNS records keep certificate/ALB/CDN dependencies acyclic.", "Detailed dependency graph: module-structure.mmd. I/O contracts: module READMEs and report."], "body", step=25)
    svg.append('</svg>')
    return "\n".join(svg)


def main():
    (ROOT / "docs/architecture.svg").write_text(architecture(), encoding="utf-8")
    (ROOT / "docs/module-structure.svg").write_text(modules(), encoding="utf-8")
    print("Generated architecture.svg and module-structure.svg.")


if __name__ == "__main__":
    main()
