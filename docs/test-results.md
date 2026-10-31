# Test results

## Final integrated checkpoint — 2026-11-01

Scope: the complete configured architecture. No real deployment or runtime application test has occurred. The source test permits the plan-only route used here.

| Check | Actual result | Status / evidence |
|---|---|---|
| Locked provider initialization | Terraform 1.17.1; AWS 6.71.0; random 3.9.1 | PASS; final-checks.txt |
| Formatting and validation | Current root and nine modules valid | PASS; final-checks.txt |
| Real full Terraform plan | 108 additions, 0 changes, 0 deletions | PASS; terraform-plan.txt |
| Full-plan integration checks | 9 checks: RDS privacy/encryption/password management; ASG bounds/ELB attachment; correct certificate provider and matching origin hostname; origin HTTPS; dynamic/error cache disabled | PASS; plan-summary.json |
| Terraform mocked suite | 14 runs passed, 0 failed, including external/Route 53 certificate branches and ALB/CDN behavior | PASS; final-checks.txt |
| Python initializer unit tests | Four fake-client cases pass | PASS; final-checks.txt |
| Shell/PHP/payload checks | Bash syntax; three PHP files; SSL verification flags; valid gzip/base64 payload, 5588 bytes in fixture | PASS; final-checks.txt |
| Artifact consistency | Initializer ZIP matches handler source and locked RDS CA; PyMySQL 1.1.2 included | PASS; final-checks.txt |
| PDF | Nine nonempty pages; required caveats and result statements present; representative diagrams/pages visually reviewed | PASS; report-checks.json |
| Extracted bundle reproduction | Manifest/source hashes match; init and plain validate pass; 14 mock runs pass from extracted source with verified local providers | PASS; reproduction-checks.txt |
| DNS ownership, ACM issuance and HTTPS handshake | No owned domain/zone, no deployment | NOT RUN |
| WordPress login/cache/REST, actual EFS/TLS/IAM denial, bootstrap/replacement/restore | No deployed resources | NOT RUN |
| Real CPU >80% / <40% for 30 minutes and resulting scaling | No deployed instances; forced/shortened tests are not substituted | NOT RUN |

`school.example.com`, `origin.example.com` and administrator email examples are planning placeholders. The real plan proves that the configured graph can be planned with AWS credentials; it does not prove those names are controlled or deployable. Some provider/data reads are deferred until apply. No secret values, raw JSON, state or binary saved plans are included in public evidence.

The current plan is `.private/full.tfplan` with private text `.private/full-plan.txt`. A sanitized text view, derived summary and source hashes are under `evidence/`. Runtime test steps and expected results are in `docs/test-plan.md`. All sections below are historical checkpoints and are superseded by this integrated result.

## Historical network checkpoint

Date: 2026-10-31 (Asia/Bangkok). Scope: network module only.

Tools: Terraform 1.17.1, AWS provider 6.71.0, Windows AMD64.

| Check | Actual result | Status |
|---|---|---|
| Recursive Terraform formatting | All Terraform files formatted | PASS |
| Provider/module initialization | Local network module and locked AWS provider initialized | PASS |
| Terraform validate | Configuration valid | PASS |
| Two-AZ mocked deployment | Six subnet CIDRs, no auto-assigned public IPs, explicit subnet associations, database table placement, same-AZ NAT routes, database ingress restrictions checked | PASS |
| Single-NAT mocked deployment | One NAT and both application default routes reference it | PASS |
| Duplicate AZ input | Rejected by variable validation as expected | PASS |
| Real network Terraform plan | Available zones resolved to `ap-southeast-2a` and `ap-southeast-2b`; 56 to add, 0 to change, 0 to destroy | PASS |
| Deployed network connectivity | Resources have not been applied | NOT RUN |
| WordPress, ALB, CloudFront, RDS, scaling and HTTPS tests | These modules are not implemented yet | NOT RUN |

`terraform test` uses `mock_provider "aws"` for every run. Its two `command = apply` runs execute only against that mock, generating synthetic resource IDs so route references can be checked. They do not create AWS resources or prove runtime connectivity.

The real plan is stored locally at `.private/network.tfplan`, with console output at `.private/network-plan.txt`. The directory is excluded from Git and submission. The plan covers the network stage only, and must be regenerated when configuration changes.

See `evidence/network-checks.txt` for the local formatting, validation and mock-test output. The 56 planned changes include network control objects such as routes, NACL rules and associations, as well as the VPC, subnets and gateways. No real infrastructure has been created by these checks.

## Subsequent security and data-services checkpoint

The network-only results above are historical. The current configuration also includes security groups, RDS and EFS.

| Check | Actual result | Status |
|---|---|---|
| RDS regional engine lookup | MySQL 8.4.11 available in ap-southeast-2 | PASS |
| RDS orderable instance lookup | db.t4g.micro, MySQL 8.4.11, gp3, Multi-AZ capable, minimum 20 GiB confirmed | PASS |
| Security mock test | CloudFront ALB ingress, application-only DB/NFS sources, restricted HTTPS egress and no DB/EFS initiated egress checked | PASS |
| RDS mock test | Private, encrypted, Multi-AZ, managed master password, backups/deletion protection and required TLS checked | PASS |
| Single-AZ database lab mock plan | Single-AZ option retains private access and encryption | PASS |
| EFS mock test | Two mount targets, at-rest encryption, automatic backup, non-root access point and TLS/access-point policy guardrails checked | PASS |
| Combined mock suite | 7 runs passed, 0 failed | PASS |
| Current real Terraform plan | 79 to add, 0 to change, 0 to destroy; RDS password not configured in plan | PASS |
| MySQL TLS handshake, restricted database user and secret rotation | No real deployment or application bootstrap yet | NOT RUN |
| EFS mount, write/read across instances, authorization denials and restore | No real deployment or compute role yet | NOT RUN |

Current saved plan: `.private/data-services.tfplan`; console output: `.private/data-services-plan.txt`. They supersede the historical network-only plan and remain excluded from Git/submission. See `evidence/data-services-checks.txt` for current local validation and test output. The real plan is a provider/configuration check; resource API creation, service-linked roles, account quotas, connectivity and restore behavior remain unproven.

## Compute and initialization checkpoint — 2026-11-01

The following results supersede the earlier counts. No real apply or real Lambda invocation has occurred.

| Check | Actual result | Status |
|---|---|---|
| EC2 image lookup | Pinned AMI is Amazon-owned, available, x86_64, with /dev/xvda root device in ap-southeast-2 | PASS |
| Instance type lookup | t3.small supports x86_64 and has 2048 MiB memory | PASS |
| WordPress artifact lookup | Downloaded archive identifies core version 7.1.4; SHA256 recorded in lock manifest | PASS |
| Lambda packaging | Verified PyMySQL 1.1.2 wheel and AWS RDS CA included; managed runtime supplies boto3 | PASS |
| Terraform suite | 10 mock runs passed, including private/encrypted fleet, numeric LT version, 1–4 bounds, exact CPU thresholds/durations, policy wiring and scoped runtime IAM | PASS |
| Initializer unit suite | 4 cases passed: locked secret generation, password reuse on retry, failed-lock behavior, and lock release/credential persistence after SQL interruption | PASS |
| Bootstrap shell | Git Bash syntax checks passed for bootstrap, shared-content initialization, and Terraform-rendered user data | PASS |
| PHP checks | PHP 8.3 lint passed for config, installer and readiness script; mysqli SSL verification flags available | PASS |
| Rendered EC2 user data | Gzip/base64 payload valid, 5588 compressed bytes; credential values/master-secret pointer absent from bootstrap settings | PASS |
| Real Terraform plan | 94 additions, 0 changes, 0 deletions | PASS |
| Bootstrapping on AL2023, SSM access, Lambda/RDS connection, EFS mount and WordPress installation | No real deployment | NOT RUN |
| RDS certificate/hostname rejection and effective EFS IAM denies | Local checks verify configuration, not service behavior | NOT RUN |
| CPU above 80% / below 40% for real 30-minute windows | No instances deployed; no runtime scaling claims | NOT RUN |
| ALB/CloudFront and end-to-end HTTPS | Frontend modules not implemented; domain unavailable | NOT RUN |

Current plan: `.private/compute.tfplan`; text: `.private/compute-plan.txt`. Current local evidence: `evidence/compute-checks.txt`. Verbose mock-state output is stored privately in `.private/compute-tests.jsonl` to check the actual rendered launch-template payload. Mock `apply` runs do not make AWS calls. Python unit tests use fake secret/database clients and do not test the actual MySQL protocol, IAM enforcement or AWS connectivity.

Some data lookups inside the compute and initialization modules are deferred until a real apply because of explicit module dependency ordering. Therefore this plan does not independently prove that those future reads, resource creations or service-linked-role operations will succeed. Separate read-only EC2 lookups verified the pinned base AMI/type. `site_url` and administrator email are still explicit example placeholders.
