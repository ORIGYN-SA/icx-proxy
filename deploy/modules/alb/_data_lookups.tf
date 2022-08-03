data "aws_elb_service_account" "main" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_wafv2_web_acl" "web_acl" {
  count = var.waf_enable ? 1 : 0
  name  = var.waf_web_acl_name
  scope = "REGIONAL"
}