resource "aws_lb" "main" {
  #bridgecrew:skip=CKV2_AWS_20: "Ensure that ALB redirects HTTP requests into HTTPS ones" False positive because only HTTP is used in the development environment without a certificate.
  name               = var.alb_name
  internal           = false
  load_balancer_type = var.load_balancer_type
  security_groups    = [var.security_group_ids]
  subnets            = var.public_subnet_ids

  access_logs {
    bucket  = aws_s3_bucket.access_logs.bucket
    enabled = true
  }
  drop_invalid_header_fields = true
  enable_deletion_protection = true

  tags = merge({ Name = var.alb_name }, var.tags)
}

resource "aws_wafv2_web_acl_association" "web_acl_association_my_lb" {
  count        = var.waf_enable ? 1 : 0
  resource_arn = aws_lb.main.arn
  web_acl_arn  = data.aws_wafv2_web_acl.web_acl[0].arn
}

resource "aws_alb_target_group" "main" {
  name        = var.alb_tg_name
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path
    unhealthy_threshold = "2"
  }

  tags = merge({ Name = var.alb_tg_name }, var.tags)
}

# Redirect traffic to target group
resource "aws_alb_listener" "http" {
  #bridgecrew:skip=CKV_AWS_2: "Ensure ALB protocol is HTTPS"  False positive because only HTTP is used in the development environment without a certificate.
  #bridgecrew:skip=CKV_AWS_103: "Ensure that load balancer is using TLS 1.2" False positive because only HTTP is used in the development environment without a certificate.
  count             = var.tsl_certificate_arn == "" ? 1 : 0
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.main.id
    type             = "forward"
  }

}

resource "aws_alb_listener" "http_to_https" {
  count             = var.tsl_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

}
resource "aws_alb_listener" "https" {
  count             = var.tsl_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.id
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.tsl_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"

  default_action {
    target_group_arn = aws_alb_target_group.main.id
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "403"
    }
  }
}

resource "aws_s3_bucket" "access_logs" {
  #checkov:skip=CKV_AWS_18: "Ensure the S3 bucket has access logging enabled" Logging not needed on a logging bucket.
  #checkov:skip=CKV_AWS_144: "Ensure that S3 bucket has cross-region replication enabled" Not required to have cross region enabled.
  #checkov:skip=CKV_AWS_145: "Ensure that S3 buckets are encrypted with KMS by default" Amazon S3-Managed Encryption Keys (SSE-S3) is required for Classic Load Balancer
  bucket = "${var.alb_name}-logs-${data.aws_region.current.name}"
  tags   = merge({ Name = "${var.alb_name}-logs-${data.aws_region.current.name}" }, var.tags)
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
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = ["${aws_s3_bucket.access_logs.arn}/AWSLogs/*"]
  }
}
