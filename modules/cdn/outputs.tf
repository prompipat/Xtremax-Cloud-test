output "distribution" {
  description = "CloudFront metadata for DNS aliases, operations and smoke tests."
  value = {
    id             = aws_cloudfront_distribution.this.id
    domain_name    = aws_cloudfront_distribution.this.domain_name
    hosted_zone_id = aws_cloudfront_distribution.this.hosted_zone_id
  }
}
