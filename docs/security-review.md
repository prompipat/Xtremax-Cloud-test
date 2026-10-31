# Configuration security review

Scope: source and real Terraform plan. This is a manual review plus automated assertions, not a penetration test or proof of deployed enforcement.

| Area | Evidence/control | Result / remaining limitation |
|---|---|---|
| Public exposure | EC2 interfaces have no public IP; RDS is not public; only the ALB is internet-facing | Configuration verified; runtime reachability untested |
| Traffic restrictions | Four dedicated SGs, tier NACLs and explicit return-port rules | Verified in mocks/plan; broad ephemeral NACL overlap is constrained by SGs |
| Origin bypass | CloudFront prefix list, private generated header, ALB default 403 | Configured; alternate-distribution rejection untested |
| Viewer/origin TLS | Two ACM regions, matching origin FQDN, TLS policies and validation dependencies | Configured; example names are not owned; issuance and handshakes NOT RUN |
| Backend encryption | RDS require_secure_transport; PHP TLS flags/CA; EFS tls/iam/accesspoint | Configured; actual negative certificate/mount tests NOT RUN |
| ALB-to-EC2 hop | HTTP/80 within private subnets and SG references | Accepted assessment trade-off; not end-to-end encryption |
| Secrets | RDS manages master; Lambda writes application secret internally; Terraform stores ARNs only | No credential literals in configuration/userdata; origin header will be present in private state/plan after apply |
| Privilege separation | EC2 cannot read master secret; initializer has schema/account setup scope and one master ARN | IAM source/mocks verified; real authorization denial tests pending |
| Unavoidable IAM wildcards | SSM channel/registration and Lambda ENI control actions only | Documented; Lambda source-function guard denies code-level use of ENI actions |
| Filesystem sharing | Regional EFS, both AZ mount targets, UID/GID 48, non-root access point, NFS initialization lock | Configured; mount/locking/instance replacement not run |
| Database initialization | MySQL named lock precedes secret generation and SQL; retries reuse credentials | Four fake-client unit tests pass; actual MySQL/API behavior not run |
| Instance hardening | IMDSv2 required, encrypted EBS, no SSH/key pair, pinned AMI, scoped instance role | Configured; OS package installation and SSM connectivity not run |
| Cache isolation | Dynamic TTL 0, cookies/queries forwarded, errors TTL 0; narrow public-image caching | Configured; login/nonce/cache leakage runtime tests pending; private media plugins need cache redesign |
| Backups/deletion | RDS seven-day backups, final snapshot and deletion protection; EFS backup enabled | Configuration verified; account backup plan/retention and restore untested |
| Updates/rotation | Pinned WordPress and checksummed downloads; UI file updates disabled | Release maintenance and application-secret rotation are operational procedures, not automated here |
| Observability | RDS/Lambda logs with retention, EC2 detailed monitoring, ASG metrics and CPU alarms | HTTP access logs, account-wide CloudTrail, Session Manager content logging and production alert routing not provisioned |
| Production hardening | Security response headers; no public application administration ports | WAF, Shield Advanced, CSP tuning, remote state/locking and DR expansion remain optional follow-up decisions |
| Submission hygiene | Allowlisted ZIP, sanitized plan, excluded real tfvars/state/provider/cache/private directories | Checked during packaging; user must keep any later runtime evidence redacted |

No static scanner result is claimed. The controls above do not imply that the undeployed application has passed connectivity, exploit, TLS, restore or scaling-duration tests.
