# storage

Creates encrypted Regional EFS with two mount targets, a WordPress access point and policy guardrails.

Inherits the root AWS provider and project tags. This module's mocked tests do not create AWS resources.

## Inputs

| Name | Description |
|---|---|
| `name` | EFS resource name prefix. |
| `subnet_ids` | Application subnet IDs keyed by availability zone. |
| `security_group_id` | EFS security group accepting NFS only from application instances. |

## Outputs

| Name | Description |
|---|---|
| `file_system` | Filesystem and access-point identifiers for the future EC2 role and mount. |
| `mount_target_ids` | Mount target IDs by AZ; compute must wait for mount targets before bootstrapping. |

See `variables.tf` for exact types, defaults and validation. The complete architecture, dependencies and limitations are in the root `docs/report.md` and `docs/report.pdf`.
