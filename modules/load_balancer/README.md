# load_balancer

Creates the public HTTPS ALB, default-deny listener, private-header forwarding rule and instance target group.

Inherits the root AWS provider and project tags. This module's mocked tests do not create AWS resources.

## Inputs

| Name | Description |
|---|---|
| `name` | ALB and target-group name prefix. |
| `vpc_id` | Application VPC ID. |
| `subnet_ids` | Public subnet IDs in two AZs. |
| `security_group_id` | ALB SG allowing HTTPS from the CloudFront managed prefix list. |
| `certificate_arn` | Validated origin ACM certificate in the ALB region. |
| `origin_header_value` | Private value shared only between this listener and the CloudFront origin. |

## Outputs

| Name | Description |
|---|---|
| `target_group_arn` | Instance target group attached to the ASG. |
| `dns_name` | ALB alias target; do not use as CloudFront HTTPS origin hostname. |
| `zone_id` | ALB canonical hosted-zone ID for Route 53 alias records. |

See `variables.tf` for exact types, defaults and validation. The complete architecture, dependencies and limitations are in the root `docs/report.md` and `docs/report.pdf`.
