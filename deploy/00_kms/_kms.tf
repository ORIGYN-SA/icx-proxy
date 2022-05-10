resource "aws_kms_key" "kms_key" {
}

resource "aws_kms_alias" "kms_key" {
  name          = local.kms_alias
  target_key_id = aws_kms_key.kms_key.key_id
}