# OAC for cloudfront to access s3 bucket without being public
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.project_name}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
# CloudFront distribution
resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name} CDN - static assets + app origin"
  price_class     = "PriceClass_100"
  aliases         = var.domain_aliases

  # Origin 1: ALB (dynamic app traffic, not cached by default)
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 8080
      https_port             = 8443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Origin 2: S3 (static product images/uploads, cached)
  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # Default behavior: everything else goes to the app (ALB)
  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    # Dynamic app responses aren't cached - CloudFront just forwards, ALB decides
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  # Static behavior: product images/uploads served from S3, cached
  ordered_cache_behavior {
    path_pattern           = "/uploads/*"
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern           = "/processed/*"
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  dynamic "viewer_certificate" {
    for_each = var.acm_certificate_arn != "" ? [1] : []
    content {
      acm_certificate_arn      = var.acm_certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1.2_2021"
    }
  }

  dynamic "viewer_certificate" {
    for_each = var.acm_certificate_arn == "" ? [1] : []
    content {
      cloudfront_default_certificate = true
    }
  }

  tags = {
    Name = "${var.project_name}-cdn"
  }
}


# AWS managed cache policies - reused instead of hand-rolling equivalents
# it Keeps files in the cache for a long time and sends only needed data to your server.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}
# it stops CloudFront from saving any files in the cache.
data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}
# This will forwards all viewer information, like headers and cookies, straight to your origin server.
data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

