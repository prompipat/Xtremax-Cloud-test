# initialization

Creates a dedicated private Lambda initializer and application-secret metadata; invokes initialization at apply only.

Inherits the root AWS provider and project tags. This module's mocked tests do not create AWS resources.

## Inputs

| Name | Description |
|---|---|
| `name` | Prefix for initializer resources. |
| `subnet_ids` | Private application subnets with NAT access to Secrets Manager. |
| `security_group_id` | Application SG, providing access to the private DB and HTTPS APIs. |
| `db_address` | RDS endpoint used with TLS hostname verification. |
| `master_secret_arn` | RDS-managed master secret; never granted to the EC2 runtime role. |
| `package_file` | ZIP built with scripts/prepare-artifacts.py before Terraform plan. |

## Outputs

| Name | Description |
|---|---|
| `application_secret_arn` | Application secret ARN only; the value is created inside Lambda at apply time. |
| `ready` | True after successful initialization; root compute dependency waits for this module. |

See `variables.tf` for exact types, defaults and validation. The complete architecture, dependencies and limitations are in the root `docs/report.md` and `docs/report.pdf`.
