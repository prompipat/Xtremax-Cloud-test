resource "aws_acm_certificate" "origin" {
  domain_name       = var.origin_domain_name
  validation_method = "DNS"
  tags              = { Name = "${var.name}-origin" }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "viewer" {
  provider          = aws.us_east_1
  domain_name       = var.site_domain_name
  validation_method = "DNS"
  tags              = { Name = "${var.name}-viewer" }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "origin_validation" {
  count   = var.hosted_zone_id == null ? 0 : 1
  zone_id = var.hosted_zone_id
  name    = one(aws_acm_certificate.origin.domain_validation_options).resource_record_name
  type    = one(aws_acm_certificate.origin.domain_validation_options).resource_record_type
  records = [one(aws_acm_certificate.origin.domain_validation_options).resource_record_value]
  ttl     = 60
}

resource "aws_route53_record" "viewer_validation" {
  count   = var.hosted_zone_id == null ? 0 : 1
  zone_id = var.hosted_zone_id
  name    = one(aws_acm_certificate.viewer.domain_validation_options).resource_record_name
  type    = one(aws_acm_certificate.viewer.domain_validation_options).resource_record_type
  records = [one(aws_acm_certificate.viewer.domain_validation_options).resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "origin" {
  certificate_arn = aws_acm_certificate.origin.arn
  validation_record_fqdns = var.hosted_zone_id == null ? [
    one(aws_acm_certificate.origin.domain_validation_options).resource_record_name
  ] : [aws_route53_record.origin_validation[0].fqdn]
}

resource "aws_acm_certificate_validation" "viewer" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.viewer.arn
  validation_record_fqdns = var.hosted_zone_id == null ? [
    one(aws_acm_certificate.viewer.domain_validation_options).resource_record_name
  ] : [aws_route53_record.viewer_validation[0].fqdn]
}
