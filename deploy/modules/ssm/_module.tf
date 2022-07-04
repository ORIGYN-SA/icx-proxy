resource "aws_ssm_parameter" "ssm_param" {
  count  = length(var.ssm_parameter_list)
  name   = var.ssm_parameter_list[count.index].name
  value  = var.ssm_parameter_list[count.index].value
  type   = var.ssm_parameter_list[count.index].type
  key_id = data.aws_kms_key.key.arn
  tags   = merge({ Name = var.ssm_parameter_list[count.index].name }, var.tags)
}