resource "aws_ssm_parameter" "ssm_param" {
  count  = length(local.ssm_parameter_list)
  name   = local.ssm_parameter_list[count.index].name
  value  = local.ssm_parameter_list[count.index].value
  type   = local.ssm_parameter_list[count.index].type
  key_id = data.aws_kms_key.cmk.arn
  tags   = merge({ Name = local.ssm_parameter_list[count.index].name }, var.tags)
}