locals {
  ssm_parameter_list = [
    {
      name  = local.db_username_ssm_parameter_name
      value = "db-user",
      type  = "SecureString"
    },
    {
      name  = local.db_password_ssm_parameter_name
      value = "db-password",
      type  = "SecureString"
    }
  ]
}