# Xtremax Cloud Engineer Technical Test

Terraform project for a WordPress site on AWS. The source of requirements is `Cloud_Engineer_-_Technical_Test_-_Xtremax.pdf` (provided separately). The development plan is guidance, not an additional test requirement.

## Deliverables

- [English report PDF](docs/report.pdf) and [Markdown source](docs/report.md)
- [System diagram](docs/architecture.svg) and [module diagram](docs/module-structure.svg), with Mermaid sources
- [Test plan](docs/test-plan.md), [actual results](docs/test-results.md), [security review](docs/security-review.md)
- [Sanitized real plan](evidence/terraform-plan.txt), [derived checks](evidence/plan-summary.json) and configuration hashes
- Root plus nine modules, per-module input/output READMEs, tests, bootstrap source and initializer artifact
- Source ZIP: `submission/terraform-source.zip`, generated with an internal SHA256 manifest
- English email draft: `docs/submission-email.txt`; applicant sends all deliverables together. No email has been sent.

The PDF says deployment is optional: a real `terraform plan` can be submitted as proof. Do not report a successful plan or runtime test until it has actually run.

## Status

**Plan-only submission. No AWS resources were deployed.** The complete network, security, RDS, EFS, initializer, WordPress/ASG, certificate, ALB and CloudFront configuration is implemented and planned using profile `xtremax` in `ap-southeast-2`.

**DNS limitation:** no owned domain/zone is available. `school.example.com`, `origin.example.com` and `admin@example.com` are planning placeholders, not deployable inputs. Replace them and complete DNS validation before deployment. A successful plan does not prove certificate issuance or runtime HTTPS. Do not apply the submitted placeholder-domain plan.

Current checkpoint checks:

- `terraform fmt -check -recursive`: PASS
- `terraform init`: PASS (AWS provider 6.71.0, recorded in `.terraform.lock.hcl`)
- `terraform validate`: PASS
- `terraform test`: PASS, 14 mock-based test runs
- Python initializer unit tests: PASS, 4 cases
- Bash/PHP syntax and PHP mysqli TLS-flag checks: PASS
- Rendered user data: PASS, 5,588 compressed bytes; no credentials in bootstrap settings
- `terraform plan`: PASS for the complete configured graph; 108 to add, 0 to change, 0 to destroy
- Derived full-plan checks: PASS, 9 checks

These results verify configuration and planning, not runtime behavior. See `evidence/final-checks.txt` and `docs/test-results.md`.

## Prerequisites

Terraform >=1.12 and <2.0 (tested 1.17.1), Python >=3.10 (tested locally on 3.13), and AWS CLI/profile credentials. Install Terraform from [HashiCorp](https://developer.hashicorp.com/terraform/install). AWS 6.71.0 and random 3.9.1 are locked. Unit tests need no external Python packages.

Plan needs provider/data-source read permissions. Deployment additionally needs relevant service provisioning permissions, role-specific IAM PassRole and initializer InvokeFunction; a successful plan does not certify them. Real deployment also requires owned DNS names, a valid administrator email and an approved budget.

## Run the infrastructure checkpoint

Extract the ZIP into a new directory. Copy `terraform.tfvars.example` to `terraform.tfvars` and replace the account ID/profile with your own values. The allowlist prevents using an unintended account. Example domains may be retained only for a clearly disclosed plan-only review.

```powershell
python scripts/prepare-artifacts.py
terraform init -input=false
terraform fmt -check -recursive
terraform validate
terraform test
python -m unittest discover -s tests -p 'test_*.py' -v
New-Item -ItemType Directory -Path .private -Force
terraform plan -input=false '-out=.private/full.tfplan'
terraform show -no-color .private/full.tfplan
```

Terraform CLI 1.17.1 is installed locally in this workspace at `.tools/terraform/`. If not on PATH here, replace `terraform` with `& .\.tools\terraform\terraform.exe`. Local tools are not included in the bundle. The bundle includes a verified non-secret initializer ZIP; rebuild it only if absent or source changes. The artifact build verifies locked PyMySQL/RDS CA downloads and uses deterministic ZIP metadata. Changed upstream CA bytes fail closed and require a reviewed manifest update.

`plan` reads the current AWS account, availability zones and CloudFront managed prefix list, then proposes infrastructure resources. It does not provision them. Running a real `apply` would incur AWS charges, including NAT/public IPv4, Multi-AZ RDS, EFS and backups. Database deletion protection is enabled; review the documented teardown procedure before deploying.

Read [network](docs/network.md), [data services](docs/data-services.md), [compute](docs/compute.md) and [frontend/DNS](docs/frontend.md) for configuration and limitations. Each module README lists its inputs/outputs.

## DNS, operations and packaging

Use distinct owned site/origin names. Supply an existing public `hosted_zone_id` covering both names for managed records, or leave it null and follow `docs/frontend.md` for staged external DNS. Review a fresh untargeted plan before any authorized apply. Do not reuse the submitted placeholder plan for deployment.

Defaults are two NATs, Multi-AZ RDS and two application instances. `single_nat_gateway = true` and `db_multi_az = false` are less resilient lab options. The AMI is Sydney-specific; T3 unlimited credits can incur surplus charges. No monthly price is asserted. The private ALB-to-EC2 hop is HTTP/80. Application rotation, HTTP access logs, account CloudTrail/SSM content logging, WAF/Shield Advanced, CSP tuning and remote state are not automated.

Before teardown, preserve data, review/apply only the intended DB deletion-protection change, then review a destroy plan. Choose a unique final snapshot name and inspect retained snapshots/backups/recovery points afterward.

Keep real tfvars, state, raw JSON and saved plans private. After capturing `.private/full-plan.txt`, create a shareable view with `python scripts/summarize-plan.py --terraform terraform`. The allowlisted ZIP excludes `.private`, `.terraform`, `.tools`, `.git`, credentials, real tfvars, state and saved plans.

Optional report rebuild (separate from application prerequisites):

```powershell
python -m pip install --target .tools/report-deps -r requirements-report.txt
python scripts/generate-diagrams.py
python scripts/generate-module-docs.py
python scripts/build-report.py --browser 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
python scripts/check-report.py
python scripts/package-submission.py
```

The supplied PDF/diagrams are already built. Packaging does not publish or send email.
