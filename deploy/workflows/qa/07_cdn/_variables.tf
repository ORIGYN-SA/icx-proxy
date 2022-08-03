variable "acm_certificate_arn" {
  default = null
}
variable "cloudfront_default_certificate" {
  default = true
}
variable "domain_name" {
  default = null
}
variable "cloudfront_cache_policy" {
  default = "CachingOptimized"
}
variable "waf_enable" {
  default = false
}
variable "waf_web_acl_name" {
  default = ""
}