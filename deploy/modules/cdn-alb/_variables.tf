variable "alb_name" {}
variable "is_ipv6_enabled" {
  default = false
}
variable "http_port" {
  default = "80"
}
variable "https_port" {
  default = "443"
}
variable "origin_protocol_policy" {
  default = "https-only"
}
variable "domain_name" {
  default = null
}
variable "origin_ssl_protocols" {
  default = ["TLSv1", "TLSv1.1", "TLSv1.2"]
}
variable "allowed_methods" {
  default = ["GET", "HEAD"]
}
variable "cached_methods" {
  default = ["GET", "HEAD"]
}
variable "compress" {
  default = true
}
variable "georestrictions_cloudfornt" {
  type    = list(any)
  default = null
}
variable "price_class" {
  default = "PriceClass_All"
}
variable "comment" {
  default = "created with terraform"
}
variable "cloudfront_default_certificate" {
  default = true
}
variable "acm_certificate_arn" {
  default = null
}
variable "ssl_support_method" {
  default = "sni-only"
}
variable "viewer_protocol_policy" {
  default = "redirect-to-https"
}
variable "minimum_protocol_version" {
  default = "TLSv1"
}
variable "tags" {}