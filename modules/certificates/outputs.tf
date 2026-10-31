output "origin_certificate_arn" {
  description = "Regional ALB certificate, gated on successful DNS validation."
  value       = aws_acm_certificate_validation.origin.certificate_arn
}

output "viewer_certificate_arn" {
  description = "us-east-1 CloudFront certificate, gated on successful DNS validation."
  value       = aws_acm_certificate_validation.viewer.certificate_arn
}

output "dns_validation_records" {
  description = "Public ACM CNAMEs; create these manually when using external DNS."
  value = {
    origin = aws_acm_certificate.origin.domain_validation_options
    viewer = aws_acm_certificate.viewer.domain_validation_options
  }
}

output "managed_validation_record_count" {
  description = "Number of Terraform-managed ACM validation CNAME records (zero for external DNS)."
  value       = length(aws_route53_record.origin_validation) + length(aws_route53_record.viewer_validation)
}
