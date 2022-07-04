resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.app_name_prefix}-ecsTaskExecutionRole-${var.environment}"
  tags = merge({ Name = "${var.app_name_prefix}-ecsTaskExecutionRole-${var.environment}" }, var.tags)

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.app_name_prefix}-ecsTaskRole-${var.environment}"
  tags = merge({ Name = "${var.app_name_prefix}-ecsTaskRole-${var.environment}" }, var.tags)

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
resource "aws_iam_policy" "ssm_user_policy" {
  name   = "${var.app_name_prefix}-ssm-policy-${var.environment}"
  tags   = merge({ Name = "${var.app_name_prefix}-ssm-policy-${var.environment}" }, var.tags)
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["ssm:DescribeParameters"],
        "Resource": ["*"]
      },
      {
        "Effect": "Allow",
        "Action": ["ssm:GetParameter","ssm:GetParameters","secretsmanager:GetSecretValue"],
        "Resource": ["${data.aws_ssm_parameter.db_password.arn}", "${data.aws_ssm_parameter.db_username.arn}"]
      },
      {
        "Effect": "Allow",
        "Action": ["kms:Decrypt"],
        "Resource": ["${data.aws_kms_key.key.arn}"]
      }
   ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "ecs-task-execution-ssm-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ssm_user_policy.arn
}
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "ecs-task-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}