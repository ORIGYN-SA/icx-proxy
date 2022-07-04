data "aws_lb" "alb" {
  name = var.alb_name
}
data "aws_cloudfront_cache_policy" "managed-cachingoptimized" {
  name = "Managed-CachingOptimized"
}
data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}
