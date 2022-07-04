resource "aws_kms_key" "kms_key" {
  tags = merge({ Name = var.kms_name }, var.tags)
}

resource "aws_kms_alias" "kms_key" {
  name          = "alias/${var.kms_name}"
  target_key_id = aws_kms_key.kms_key.key_id
}