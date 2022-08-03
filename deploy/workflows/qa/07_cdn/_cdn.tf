module "cdn" {
  source = "../../../modules/cdn-alb"

  alb_name                       = local.alb_name
  cdn_name                       = local.cdn_name
  acm_certificate_arn            = var.acm_certificate_arn
  cloudfront_default_certificate = var.cloudfront_default_certificate
  domain_name                    = var.domain_name
  cloudfront_cache_policy        = var.cloudfront_cache_policy
  waf_enable                     = var.waf_enable
  waf_web_acl_name               = var.waf_web_acl_name
  tags                           = local.common_tags
}