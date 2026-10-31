# certificates

Requests and validates separate origin and viewer ACM certificates, with optional Route 53 validation records.

Inherits the root AWS provider and project tags. This module's mocked tests do not create AWS resources.

Requires the `aws.us_east_1` provider alias for the viewer certificate; the default provider creates the origin certificate.

## Inputs

| Name | Description |
|---|---|
| `name` | Certificate tag prefix. |
| `site_domain_name` | Owned public site DNS name, without a scheme or path. |
| `origin_domain_name` | Owned origin DNS name matching the ALB certificate. |
| `hosted_zone_id` | Public Route 53 zone for both names, or null for external DNS validation. |

## Outputs

| Name | Description |
|---|---|
| `origin_certificate_arn` | Regional ALB certificate, gated on successful DNS validation. |
| `viewer_certificate_arn` | us-east-1 CloudFront certificate, gated on successful DNS validation. |
| `dns_validation_records` | Public ACM CNAMEs; create these manually when using external DNS. |
| `managed_validation_record_count` | Number of Terraform-managed ACM validation CNAME records (zero for external DNS). |

See `variables.tf` for exact types, defaults and validation. The complete architecture, dependencies and limitations are in the root `docs/report.md` and `docs/report.pdf`.
