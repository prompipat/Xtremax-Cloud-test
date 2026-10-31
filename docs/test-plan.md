# Test plan and requirement mapping

Scope: a plan-only submission. Execute static/configuration checks now; execute runtime cases only in an authorized, budgeted deployment with owned DNS names. Do not mark runtime cases PASS from mocks, plan output, manually forced alarm states or shortened alarm durations.

## Configuration tests

Preconditions for V01–V08: Python 3.10+, Terraform 1.12+ (tested 1.17.1), the included artifact or a successful artifact build, locked providers, and the submitted source revision. V03 additionally requires a valid AWS profile and read permissions. Examples can be used to inspect the plan, but must be disclosed as placeholders.

| ID | Requirements | Steps | Expected result | Evidence |
|---|---|---|---|---|
| V01 | R01 | Run `terraform fmt -check -recursive` | Exit 0 | evidence/final-checks.txt |
| V02 | R01 | Run `terraform init` and `terraform validate` | Locked providers initialize; configuration valid | evidence/final-checks.txt |
| V03 | R01–R11 | Run untargeted `terraform plan -out=...`; render text; sanitize it | Full graph plans successfully; no hidden creation/validation errors | evidence/terraform-plan.txt; plan-summary.json |
| V04 | R08, R10–R11 | Run mock suite and inspect actual planned routes, SGs, RDS and IAM references | Private/encrypted DB; correct subnet routes and SG boundaries; no EC2 master-secret read | tests/*.tftest.hcl; final-checks.txt |
| V05 | R04–R07 | Inspect LT/ASG/alarms and run compute mock tests | Private encrypted IMDSv2 fleet; min 1/max 4; >80/<40, 6 of 6 × 300s; ±1 policies wired correctly | tests/compute.tftest.hcl; plan-summary.json |
| V06 | R02–R03, R09 | Run frontend/certificate mock tests and inspect actual full-plan provider wiring | Regional origin ACM, us-east-1 viewer ACM; origin HTTPS; ALB 403 default; dynamic/error caches disabled | tests/frontend.tftest.hcl; tests/certificates.tftest.hcl; plan-summary.json |
| V07 | R04, R11 | Run Python initializer unit tests, Bash/PHP syntax checks and rendered payload check | Safe retry/locking and schema-scoped SQL; no passwords in userdata; payload within 16 KiB | tests/test_initializer.py; scripts/check-rendered-userdata.py; final-checks.txt |
| V08 | R12–R15 | Extract submission ZIP; initialize with locked providers; validate/test; inspect artifact manifest and exclusions | Usable source bundle, current diagrams/report, no credentials/state/private plans/provider directories | evidence/reproduction-checks.txt; submission manifest |

Mocks use synthetic service values and never verify AWS runtime enforcement. V03 verifies a real provider plan, not public DNS ownership, issued certificates, account quotas or application behavior.

## Runtime test cases

Common preconditions: replace every example DNS/email value, own/validate DNS, obtain approved deployment budget, review/apply a fresh full plan, wait for certificates/distribution/instances, and record AWS account/region, UTC/local time and artifact hashes privately. Keep screenshots/logs free of credentials and private origin-header values. Each test starts NOT RUN until evidence exists.

| ID | Requirements | Steps | Expected result | Initial status / evidence to collect |
|---|---|---|---|---|
| RT01 | R02–R04, R09 | Request HTTP and HTTPS site URL; inspect certificate chain and final response | HTTP redirects; valid viewer TLS; WordPress loads without mixed-content/redirect loops | NOT RUN; sanitized HTTP/TLS output |
| RT02 | R02, R04 | Log in; load wp-admin; create/update a draft; perform authenticated REST/AJAX requests; repeat in a separate anonymous browser | Cookies/nonces/POST work; authenticated content is not served from a shared cache | NOT RUN; two-browser request traces |
| RT03 | R02 | Upload a public image; request it repeatedly with identical query; inspect `X-Cache`/Age; request admin pages repeatedly | Public image can hit edge cache; dynamic/admin pages do not become shared hits | NOT RUN; sanitized response headers |
| RT04 | R03–R04 | Inspect target health; request through ALB/CloudFront with desired capacity 2; track instance logs privately | Both targets healthy and serve consistent site/database state | NOT RUN; target-health output and request evidence |
| RT05 | R04 | Upload media through one instance; read through another; terminate/replace an instance through ASG | Media/theme content survives and replacement bootstraps without manual configuration | NOT RUN; EFS/readback/replacement logs |
| RT06 | R08–R11 | From the workload, connect with correct CA/hostname; attempt plaintext and wrong-CA/hostname connections; attempt public DB access | Valid TLS works; insecure/mismatched/public access fails | NOT RUN; sanitized client results; no password arguments |
| RT07 | R09–R10 | Request the ALB origin directly without the header; exercise a controlled alternate-distribution test without the private value | Public direct traffic is blocked by SG; CloudFront-range requests without the value receive 403 | NOT RUN; rejection/403 evidence; do not expose the header |
| RT08 | R05–R06 | Apply sustained CPU load across the ASG above 80%; retain six complete 300s periods and scaling activity logs | Alarm breaches and adds capacity within max 4, accounting for evaluation/warmup | NOT RUN; metric/alarm/scaling history spanning real 30-minute condition |
| RT09 | R05, R07 | Stop load and retain six complete below-40% periods after warmup | Scale in by policy and remain at or above min 1 | NOT RUN; metric/alarm/scaling history |
| RT10 | R06–R07 | Test missing samples and return-to-normal behavior in a controlled environment | Missing data alone does not trigger scale actions; recovery matches documented evaluation | NOT RUN; alarm state history and metric timestamps |
| RT11 | R10–R11 | With the instance role, read only the app secret; attempt master-secret read, wrong EFS access point and non-TLS mount | Required access works; unauthorized actions fail; no secret enters journal/cloud-init logs | NOT RUN; redacted authorization results |
| RT12 | R04, R08 | Launch/retry initialization; test a restored backup in an isolated environment; replace instances and inspect logs | No duplicate schema/content initialization; restored app data is usable | NOT RUN; restore and retry evidence |
| RT13 | R05, R12 | Tag/check billable resources, review destroy plan, disable DB deletion protection intentionally, teardown and inspect retained data | Ephemeral resources removed; retained snapshots/backups/logs/secrets explicitly accounted for | NOT RUN; cleanup inventory and billing follow-up |

Artificial `set-alarm-state` checks prove only part of action wiring. They do not satisfy RT08/RT09. Capture actual results, timestamps and evidence paths in `docs/test-results.md` for every runtime case performed.

## Source requirements

R01 Terraform; R02 CloudFront; R03 ALB; R04 WordPress EC2 ASG; R05 ASG bounds; R06 scale out; R07 scale in; R08 RDS MySQL; R09 HTTPS; R10 SG/NACL; R11 IAM least privilege; R12 architecture/security documentation; R13 test plan/results; R14 system/module diagrams and I/O; R15 ZIP and one-email submission. These identifiers match the supplied development plan.
