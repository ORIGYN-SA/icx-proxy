locals {
  environment = "dev"
  tags = {
    "ogy:required:environment_name" = local.environment
  }
}
