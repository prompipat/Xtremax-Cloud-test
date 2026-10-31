mock_provider "aws" {
  mock_resource "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:loadbalancer/app/test/0123456789abcdef" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:targetgroup/test/0123456789abcdef" }
  }
  mock_resource "aws_lb_listener" {
    defaults = { arn = "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:listener/app/test/0123456789abcdef/0123456789abcdef" }
  }
  mock_resource "aws_cloudfront_origin_request_policy" {
    defaults = { id = "11111111-1111-4111-8111-111111111111" }
  }
  mock_resource "aws_cloudfront_response_headers_policy" {
    defaults = { id = "22222222-2222-4222-8222-222222222222" }
  }
}

run "alb_origin_gate_and_readiness" {
  command = apply
  module { source = "./modules/load_balancer" }
  variables {
    name                = "frontend-test"
    vpc_id              = "vpc-0123456789abcdef0"
    subnet_ids          = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_id   = "sg-0123456789abcdef0"
    certificate_arn     = "arn:aws:acm:ap-southeast-2:123456789012:certificate/01234567-89ab-cdef-0123-456789abcdef"
    origin_header_value = "TEST_ONLY_HEADER_NOT_A_SECRET"
  }

  assert {
    condition = (
      aws_lb_listener.https.port == 443 && aws_lb_listener.https.protocol == "HTTPS" &&
      one(one(aws_lb_listener.https.default_action).fixed_response).status_code == "403"
    )
    error_message = "The listener must terminate HTTPS and reject requests by default."
  }

  assert {
    condition = (
      one(one(aws_lb_listener_rule.cloudfront_only.condition).http_header).http_header_name == "X-Xtremax-Origin-Verify" &&
      contains(one(one(aws_lb_listener_rule.cloudfront_only.condition).http_header).values, var.origin_header_value) &&
      one(aws_lb_listener_rule.cloudfront_only.action).target_group_arn == aws_lb_target_group.wordpress.arn
    )
    error_message = "Only requests with the origin header may forward to the ASG target group."
  }

  assert {
    condition = (
      aws_lb_target_group.wordpress.target_type == "instance" && aws_lb_target_group.wordpress.protocol == "HTTP" &&
      one(aws_lb_target_group.wordpress.health_check).path == "/health.php" &&
      one(aws_lb_target_group.wordpress.health_check).matcher == "200"
    )
    error_message = "The ASG-compatible target group must check application/database readiness."
  }
}

run "cdn_https_dynamic_and_static_cache" {
  command = apply
  module { source = "./modules/cdn" }
  variables {
    name                   = "frontend-test"
    site_domain_name       = "school.example.com"
    origin_domain_name     = "origin.example.com"
    viewer_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/01234567-89ab-cdef-0123-456789abcdef"
    origin_header_value    = "TEST_ONLY_HEADER_NOT_A_SECRET"
  }

  override_resource {
    target = aws_cloudfront_cache_policy.dynamic
    values = { id = "33333333-3333-4333-8333-333333333333" }
  }
  override_resource {
    target = aws_cloudfront_cache_policy.public_images
    values = { id = "44444444-4444-4444-8444-444444444444" }
  }

  assert {
    condition = (
      one(aws_cloudfront_distribution.this.default_cache_behavior).viewer_protocol_policy == "redirect-to-https" &&
      one(one(aws_cloudfront_distribution.this.origin).custom_origin_config).origin_protocol_policy == "https-only" &&
      one(aws_cloudfront_distribution.this.origin).domain_name == var.origin_domain_name &&
      one(aws_cloudfront_distribution.this.viewer_certificate).minimum_protocol_version == "TLSv1.2_2021"
    )
    error_message = "Viewer and origin must enforce HTTPS using the certificate-matching origin hostname."
  }

  assert {
    condition = (
      aws_cloudfront_cache_policy.dynamic.max_ttl == 0 &&
      one(aws_cloudfront_distribution.this.default_cache_behavior).cache_policy_id == aws_cloudfront_cache_policy.dynamic.id &&
      contains(one(aws_cloudfront_distribution.this.default_cache_behavior).allowed_methods, "POST") &&
      one(aws_cloudfront_origin_request_policy.dynamic.cookies_config).cookie_behavior == "all" &&
      one(aws_cloudfront_origin_request_policy.dynamic.query_strings_config).query_string_behavior == "all" &&
      one(aws_cloudfront_origin_request_policy.dynamic.headers_config).header_behavior == "allExcept" &&
      contains(one(one(aws_cloudfront_origin_request_policy.dynamic.headers_config).headers).items, "Host")
    )
    error_message = "Dynamic WordPress traffic must remain uncached and preserve cookies, queries and authorization-related viewer headers."
  }

  assert {
    condition = (
      length(aws_cloudfront_distribution.this.ordered_cache_behavior) == 6 &&
      alltrue([for behavior in aws_cloudfront_distribution.this.ordered_cache_behavior :
        startswith(behavior.path_pattern, "/wp-content/uploads/*.") &&
        behavior.cache_policy_id == aws_cloudfront_cache_policy.public_images.id &&
        !contains(behavior.allowed_methods, "POST")
      ]) && aws_cloudfront_cache_policy.public_images.min_ttl == 0
    )
    error_message = "Cache only the selected public upload image extensions; honor origin no-store/private directives."
  }

  assert {
    condition     = alltrue([for error in aws_cloudfront_distribution.this.custom_error_response : error.error_caching_min_ttl == 0])
    error_message = "Errors must not retain CloudFront's default error cache TTL."
  }
}
