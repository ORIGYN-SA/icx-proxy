resource "aws_kms_key" "kms_key" {
  enable_key_rotation = true

  tags   = merge({ Name = var.kms_name }, var.tags)
  policy = data.aws_iam_policy_document.encryption_key.json
}

resource "aws_kms_alias" "kms_key" {
  name          = "alias/${var.kms_name}"
  target_key_id = aws_kms_key.kms_key.key_id
}

data "aws_iam_policy_document" "encryption_key" {
  #bridgecrew:skip=CKV_AWS_109: "Ensure IAM policies does not allow permissions management / resource exposure without constraints" False positive as this is attached as a key policy and is implicitly constrained by the key.
  #bridgecrew:skip=CKV_AWS_111: "Ensure IAM policies does not allow write access without constraints" False positive as this is attached as a key policy and is implicitly constrained by the key.
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "Enable Cloudwatch Log encryption"
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}