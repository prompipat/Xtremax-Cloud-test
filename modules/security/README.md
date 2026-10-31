# security

Creates dedicated ALB, application, database and EFS security groups and stateful traffic rules.

Inherits the root AWS provider and project tags. This module's mocked tests do not create AWS resources.

## Inputs

| Name | Description |
|---|---|
| `name` | Resource name prefix. |
| `vpc_id` | VPC containing all workload security groups. |

## Outputs

| Name | Description |
|---|---|
| `security_group_ids` | Dedicated security group IDs keyed by workload tier. |

See `variables.tf` for exact types, defaults and validation. The complete architecture, dependencies and limitations are in the root `docs/report.md` and `docs/report.pdf`.
