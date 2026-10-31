# cdn

Creates the custom-domain HTTPS CloudFront distribution and safe WordPress cache/response-header policies.

Inherits the root AWS provider and project tags. This module's mocked tests do not create AWS resources.

## Inputs

| Name | Description |
|---|---|
| `name` | CloudFront policy name prefix. |
| `site_domain_name` | Custom site alias covered by the us-east-1 viewer certificate. |
| `origin_domain_name` | Origin DNS name pointing to the ALB and covered by its regional certificate. |
| `viewer_certificate_arn` | Validated viewer ACM certificate in us-east-1. |
| `origin_header_value` | Private value matched by the ALB listener. |

## Outputs

| Name | Description |
|---|---|
| `distribution` | CloudFront metadata for DNS aliases, operations and smoke tests. |

See `variables.tf` for exact types, defaults and validation. The complete architecture, dependencies and limitations are in the root `docs/report.md` and `docs/report.pdf`.
