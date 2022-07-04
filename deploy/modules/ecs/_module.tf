resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.ecs_task_definition_name}"
  retention_in_days = 90
  tags              = merge({ Name = var.ecs_task_definition_name, Environment = var.environment }, var.tags)
}

resource "aws_ecs_task_definition" "main" {
  family                   = var.ecs_task_definition_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
    name      = "${var.app_name_prefix}-container-${var.environment}"
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

  tags = merge({ Name = var.ecs_task_definition_name }, var.tags)
}

resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name
  tags = merge({ Name = var.ecs_cluster_name }, var.tags)
  setting {
    name  = "containerInsights"
    value = var.enable_containerInsights
  }
}

resource "aws_ecs_service" "main" {
  name                               = var.ecs_service_name
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
    security_groups  = [var.security_group_ids]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_tg_group_arn
    container_name   = "${var.app_name_prefix}-container-${var.environment}"
    container_port   = var.container_port
  }
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
  tags = merge({ Name = var.ecs_service_name }, var.tags)
}
