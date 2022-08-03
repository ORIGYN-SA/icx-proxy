resource "aws_ecr_repository" "main" {
  name                 = var.ecr_name
  image_tag_mutability = "IMMUTABLE"
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = data.aws_kms_key.key.arn
  }
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = merge({ Name = var.ecr_name }, var.tags)
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 10 images"
      action = {
        type = "expire"
      }
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
    }]
  })
}