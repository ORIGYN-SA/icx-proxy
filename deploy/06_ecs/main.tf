resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.name_prefix}-ecsTaskExecutionRole-${var.environment}"

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
  name = "${local.name_prefix}-ecsTaskRole-${var.environment}"

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
  name = "${local.name_prefix}-ssm-policy-${var.environment}"
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
        "Resource": ["${data.aws_kms_key.cmk.arn}"]
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

resource "aws_cloudwatch_log_group" "main" {
  name = "/ecs/${local.name_prefix}-task-${var.environment}"

  tags = {
    Name        = "${local.name_prefix}-task-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${local.name_prefix}-task-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
    name      = "${local.name_prefix}-container-${var.environment}"
    image     = "${data.aws_ecr_repository.service.repository_url}:latest"
    essential = true
    environment = [
      { name = "LOG_LEVEL",
      value = "DEBUG" }
    ]
    portMappings = [{
      protocol      = "tcp"
      containerPort = var.container_port
      hostPort      = var.container_port
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.main.name
        awslogs-stream-prefix = "ecs"
        awslogs-region        = data.aws_region.current.name
      }
    }
  }])

  tags = {
    Name = "${local.name_prefix}-task-${var.environment}"
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster-${var.environment}"
  tags = {
    Name = "${local.name_prefix}-cluster-${var.environment}"
  }
}

resource "aws_ecs_service" "main" {
  name                               = local.ecs_service_name
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.main.arn
  desired_count                      = var.service_desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  platform_version                   = "1.3.0"

  network_configuration {
    security_groups  = [data.aws_security_group.ecs.id]
    subnets          = data.aws_subnets.public_subnets.ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = data.aws_lb_target_group.alb_tg_group.arn
    container_name   = "${local.name_prefix}-container-${var.environment}"
    container_port   = var.container_port
  }
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
