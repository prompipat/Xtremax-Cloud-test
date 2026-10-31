resource "aws_cloudfront_cache_policy" "dynamic" {
  name        = "${var.name}-dynamic"
  min_ttl     = 0
  default_ttl = 0
  max_ttl     = 0
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config { cookie_behavior = "none" }
    headers_config { header_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }
  }
}

resource "aws_cloudfront_origin_request_policy" "dynamic" {
  name = "${var.name}-dynamic"
  cookies_config { cookie_behavior = "all" }
  query_strings_config { query_string_behavior = "all" }
  headers_config {
    header_behavior = "allExcept"
    headers { items = ["Host"] }
  }
}

resource "aws_cloudfront_cache_policy" "public_images" {
  name        = "${var.name}-public-images"
  min_ttl     = 0
  default_ttl = 86400
  max_ttl     = 604800
  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
    cookies_config { cookie_behavior = "none" }
    headers_config { header_behavior = "none" }
    query_strings_config { query_string_behavior = "all" }
  }
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${var.name}-security"
  security_headers_config {
    content_type_options { override = true }
    frame_options {
      frame_option = "SAMEORIGIN"
      override     = false
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = false
      preload                    = false
      override                   = true
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  aliases         = [var.site_domain_name]
  comment         = "WordPress: dynamic cache disabled; public upload images cached"
  price_class     = "PriceClass_All"
  http_version    = "http2and3"

  origin {
    origin_id   = "wordpress-alb"
    domain_name = var.origin_domain_name
    custom_header {
      name  = "X-Xtremax-Origin-Verify"
      value = var.origin_header_value
    }
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id           = "wordpress-alb"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = aws_cloudfront_cache_policy.dynamic.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.dynamic.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = true
  }

  dynamic "ordered_cache_behavior" {
    for_each = ["jpg", "jpeg", "png", "gif", "webp", "avif"]
    content {
      path_pattern               = "/wp-content/uploads/*.${ordered_cache_behavior.value}"
      target_origin_id           = "wordpress-alb"
      viewer_protocol_policy     = "redirect-to-https"
      allowed_methods            = ["GET", "HEAD", "OPTIONS"]
      cached_methods             = ["GET", "HEAD"]
      cache_policy_id            = aws_cloudfront_cache_policy.public_images.id
      response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
      compress                   = true
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.viewer_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  dynamic "custom_error_response" {
    for_each = [400, 403, 404, 405, 414, 416, 500, 501, 502, 503, 504]
    content {
      error_code            = custom_error_response.value
      error_caching_min_ttl = 0
    }
  }
}
