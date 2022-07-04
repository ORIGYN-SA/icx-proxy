module "cdn" {
  source = "../../../modules/cdn-alb"

  alb_name                       = local.alb_name
  acm_certificate_arn            = var.acm_certificate_arn
  cloudfront_default_certificate = var.cloudfront_default_certificate
  domain_name                    = var.domain_name
  tags                           = local.common_tags
}