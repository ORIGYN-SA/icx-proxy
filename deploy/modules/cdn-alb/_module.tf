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
  logging_config {
    bucket = aws_s3_bucket.access_logs.bucket_domain_name
    prefix = "AWSLogs/"
  }
  #bridgecrew:skip=CKV_AWS_68: "CloudFront Distribution should have WAF enabled"
  web_acl_id = var.waf_enable ? data.aws_wafv2_web_acl.web_acl[0].id : ""
  #bridgecrew:skip=CKV2_AWS_32: "Ensure CloudFront distribution has a response headers policy attached". False positive because aws_cloudfront_response_headers_policy is enabled.
  default_cache_behavior {
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.simple_cors.id

    allowed_methods          = var.allowed_methods
    cached_methods           = var.cached_methods
    target_origin_id         = data.aws_lb.alb.id
    cache_policy_id          = data.aws_cloudfront_cache_policy.cloudfront_cache_policy.id
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

  tags = merge({ Name = var.cdn_name }, var.tags)
}

resource "aws_s3_bucket" "access_logs" {
  #checkov:skip=CKV_AWS_18: "Ensure the S3 bucket has access logging enabled" Logging not needed on a logging bucket.
  #checkov:skip=CKV_AWS_144: "Ensure that S3 bucket has cross-region replication enabled" Not required to have cross region enabled.
  #checkov:skip=CKV_AWS_145: "Ensure that S3 buckets are encrypted with KMS by default" Amazon S3-Managed Encryption Keys (SSE-S3) is required for CloudFront
  bucket = "${var.cdn_name}-logs-${data.aws_region.current.name}"
  tags   = merge({ Name = "${var.cdn_name}-logs-${data.aws_region.current.name}" }, var.tags)

}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "server_side_encryption" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.access_logs.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

