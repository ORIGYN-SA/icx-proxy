data "aws_region" "current" {}
data "aws_lb" "lb" {
  name = var.lb_name
}
data "aws_cloudfront_cache_policy" "cloudfront_cache_policy" {
  name = "Managed-${var.cloudfront_cache_policy}"
}
data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}
data "aws_cloudfront_response_headers_policy" "simple_cors" {
  name = "Managed-SimpleCORS"
}
data "aws_wafv2_web_acl" "web_acl" {
  count = var.waf_enable ? 1 : 0
  name  = var.waf_web_acl_name
  scope = "REGIONAL"
}
