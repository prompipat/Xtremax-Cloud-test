# compute

Creates the restricted EC2 role/profile, WordPress launch template, ASG, CPU alarms and step-scaling policies.

Inherits the root AWS provider and project tags. This module's mocked tests do not create AWS resources.

## Inputs

| Name | Description |
|---|---|
| `name` | Resource name prefix. |
| `ami_id` | Pinned, Amazon-owned AL2023 x86_64 image ID for this region. |
| `instance_type` | x86_64 EC2 type; default is burstable with explicit unlimited credits. |
| `subnet_ids` | Private application subnet IDs. |
| `security_group_id` | Application security group. |
| `application_secret_arn` | Initialized application secret ARN; no master secret permission is granted. |
| `db_address` | Private RDS DNS endpoint, matching its TLS certificate. |
| `efs` | Filesystem and access-point metadata. |
| `downloads` | Verified release and RDS CA URLs and SHA256 checksums. |
| `site_url` | Canonical HTTPS website URL; replace any example placeholder before deployment. |
| `admin_email` | WordPress administrator email; initial admin credentials live in the application secret. |
| `desired_capacity` | Initial size; dynamic scaling subsequently owns desired capacity. |
| `target_group_arns` | ALB target groups; when supplied the ASG uses ELB health checks. |

## Outputs

| Name | Description |
|---|---|
| `autoscaling_group_name` | ASG name for operations and runtime tests. |
| `instance_role_arn` | Restricted application instance role. |
| `launch_template_id` | Versioned WordPress launch template. |

See `variables.tf` for exact types, defaults and validation. The complete architecture, dependencies and limitations are in the root `docs/report.md` and `docs/report.pdf`.
