# database

Creates private encrypted RDS MySQL with managed master credentials, backups and TLS enforcement.

Inherits the root AWS provider and project tags. This module's mocked tests do not create AWS resources.

## Inputs

| Name | Description |
|---|---|
| `name` | RDS instance and resource name prefix. |
| `subnet_ids` | Isolated subnet IDs in two availability zones. |
| `security_group_id` | Dedicated database security group permitting application MySQL only. |
| `engine_version` | Pinned RDS MySQL 8.4 version verified in the deployment region. |
| `instance_class` | RDS DB instance class. |
| `multi_az` | Provision a standby in another AZ. |
| `deletion_protection` | Prevent accidental deletion; disable explicitly before intentional teardown. |
| `final_snapshot_identifier` | Unique identifier for the final snapshot when the DB is deleted. |

## Outputs

| Name | Description |
|---|---|
| `connection` | Database metadata; contains no password or secret value. |

See `variables.tf` for exact types, defaults and validation. The complete architecture, dependencies and limitations are in the root `docs/report.md` and `docs/report.pdf`.
