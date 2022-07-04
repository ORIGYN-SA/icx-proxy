resource "aws_cloudfront_distribution" "this" {

  enabled         = true
  is_ipv6_enabled = var.is_ipv6_enabled
  comment         = var.comment
  aliases         = var.domain_name
  origin {
    domain_name = data.aws_lb.alb.dns_name
    origin_id   = data.aws_lb.alb.id

    custom_origin_config {
      http_port              = var.http_port
      https_port             = var.https_port
      origin_protocol_policy = var.origin_protocol_policy
      origin_ssl_protocols   = var.origin_ssl_protocols
    }
  }

  default_cache_behavior {
    allowed_methods          = var.allowed_methods
    cached_methods           = var.cached_methods
    target_origin_id         = data.aws_lb.alb.id
    cache_policy_id          = data.aws_cloudfront_cache_policy.managed-cachingoptimized.id
    viewer_protocol_policy   = var.viewer_protocol_policy
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    compress                 = var.compress
  }

  price_class = var.price_class

  restrictions {
    geo_restriction {
      restriction_type = var.georestrictions_cloudfornt == null ? "none" : "blacklist"
      locations        = var.georestrictions_cloudfornt == null ? null : var.georestrictions_cloudfornt
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.acm_certificate_arn
    cloudfront_default_certificate = var.cloudfront_default_certificate

    minimum_protocol_version = var.minimum_protocol_version
    ssl_support_method       = var.ssl_support_method
  }

  tags = merge({ Name = data.aws_lb.alb.name }, var.tags)
}
