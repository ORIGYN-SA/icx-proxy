terraform {
  required_version = ">= 0.13.1"

  required_providers {
    aws = ">= 3.50"
  }
  backend "s3" {
    bucket  = "terraform-state-storage-us-east-1"
    region  = "us-east-1"
    key     = "icx-proxy/load_test_infra/load_test.tfstate"
    profile = "origyn-root"
  }
}