terraform {
  source = "../../../../modules/kms"
}

include "root" {
  path = find_in_parent_folders()
}

locals {
  common_vars = read_terragrunt_config("common.hcl")
}

inputs = merge(
  local.common_vars.inputs,
  {
    # additional inputs
  }
)