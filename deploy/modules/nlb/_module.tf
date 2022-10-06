resource "aws_lb" "main" {
  #bridgecrew:skip=CKV2_AWS_20: "Ensure that ALB redirects HTTP requests into HTTPS ones" False positive because only HTTP is used in the development environment without a certificate.
  name               = var.nlb_name
  internal           = false
  load_balancer_type = var.load_balancer_type
  subnets            = var.public_subnet_ids

  access_logs {
    bucket  = aws_s3_bucket.access_logs.bucket
    enabled = true
  }
  drop_invalid_header_fields       = true
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = true
  tags                             = merge({ Name = var.nlb_name }, var.tags)
}

resource "aws_wafv2_web_acl_association" "web_acl_association_my_lb" {
  count        = var.waf_enable ? 1 : 0
  resource_arn = aws_lb.main.arn
  web_acl_arn  = data.aws_wafv2_web_acl.web_acl[0].arn
}

resource "aws_lb_target_group" "main" {
  name = var.nlb_tg_name

  port        = var.container_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = "2"
    interval            = "30"
    protocol            = "HTTP"
    path                = var.health_check_path
    unhealthy_threshold = "2"
  }

  tags = merge({ Name = var.nlb_tg_name }, var.tags)
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.id
  port              = 443
  protocol          = "TLS"
  certificate_arn   = var.tsl_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  default_action {
    target_group_arn = aws_lb_target_group.main.id
    type             = "forward"
  }
}

resource "aws_s3_bucket" "access_logs" {
  #checkov:skip=CKV_AWS_18: "Ensure the S3 bucket has access logging enabled" Logging not needed on a logging bucket.
  #checkov:skip=CKV_AWS_144: "Ensure that S3 bucket has cross-region replication enabled" Not required to have cross region enabled.
  #checkov:skip=CKV_AWS_145: "Ensure that S3 buckets are encrypted with KMS by default" Amazon S3-Managed Encryption Keys (SSE-S3) is required for Classic Load Balancer
  bucket        = "${var.nlb_name}-logs-${data.aws_region.current.name}"
  force_destroy = true
  tags          = merge({ Name = "${var.nlb_name}-logs-${data.aws_region.current.name}" }, var.tags)
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.policy_document.json
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
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "policy_document" {
  statement {
    actions   = ["s3:PutObject"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.access_logs.arn}/*"]

    principals {
      identifiers = ["delivery.logs.amazonaws.com"]
      type        = "Service"
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    actions   = ["s3:GetBucketAcl"]
    effect    = "Allow"
    resources = [aws_s3_bucket.access_logs.arn]

    principals {
      identifiers = ["delivery.logs.amazonaws.com"]
      type        = "Service"
    }
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "nlb_log" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    id = "Store logs for the last 7 days"
    expiration {
      days = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
    status = "Enabled"
  }
  rule {
    id = "Expired object delete_marker"
    expiration {
      days                         = 0
      expired_object_delete_marker = true
    }
    status = "Enabled"
  }
}