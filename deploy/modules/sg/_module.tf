#resource "aws_security_group" "alb" {
#  #bridgecrew:skip=CKV2_AWS_5: Skipping "Ensure that Security Groups are attached to another resource". False positive because when using aws_security_group and a module, its binding to the module does not work.
#  name   = var.alb_sg_name
#  vpc_id = data.aws_vpc.selected_vpc.id
#
#  tags = merge({ Name = var.alb_sg_name }, var.tags)
#
#  description = "Managed by Terraform"
#}

resource "aws_security_group" "ecs_tasks" {
  #bridgecrew:skip=CKV2_AWS_5: Skipping "Ensure that Security Groups are attached to another resource". False positive because when using aws_security_group and a module, its binding to the module does not work.
  name   = var.ecs_task_sg_name
  vpc_id = data.aws_vpc.selected_vpc.id

  tags = merge({ Name = var.ecs_task_sg_name }, var.tags)

  description = "Managed by Terraform"
}

resource "aws_security_group" "redis" {
  #bridgecrew:skip=CKV2_AWS_5: Skipping "Ensure that Security Groups are attached to another resource". False positive because when using aws_security_group and a module, its binding to the module does not work.
  name   = var.redis_sg_name
  vpc_id = data.aws_vpc.selected_vpc.id

  tags = merge({ Name = var.redis_sg_name }, var.tags)

  description = "Managed by Terraform"
}
resource "aws_security_group_rule" "ecs_rules" {
  count = length(var.ecs_sg_rules)

  security_group_id = aws_security_group.ecs_tasks.id
  type              = var.ecs_sg_rules[count.index].type
  description       = var.ecs_sg_rules[count.index].description

  cidr_blocks = var.ecs_sg_rules[count.index].cidr_blocks
  from_port   = var.ecs_sg_rules[count.index].from_port
  to_port     = var.ecs_sg_rules[count.index].to_port
  protocol    = var.ecs_sg_rules[count.index].protocol
}
#resource "aws_security_group_rule" "alb_rules" {
#  count = length(var.lb_sg_rules)
#
#  security_group_id = aws_security_group.alb.id
#  type              = var.lb_sg_rules[count.index].type
#  description       = var.lb_sg_rules[count.index].description
#
#  cidr_blocks = var.lb_sg_rules[count.index].cidr_blocks
#  from_port   = var.lb_sg_rules[count.index].from_port
#  to_port     = var.lb_sg_rules[count.index].to_port
#  protocol    = var.lb_sg_rules[count.index].protocol
#}
resource "aws_security_group_rule" "redis_rules" {
  count = length(var.redis_sg_rules)

  security_group_id = aws_security_group.redis.id
  type              = var.redis_sg_rules[count.index].type
  description       = var.redis_sg_rules[count.index].description

  cidr_blocks = var.redis_sg_rules[count.index].cidr_blocks
  from_port   = var.redis_sg_rules[count.index].from_port
  to_port     = var.redis_sg_rules[count.index].to_port
  protocol    = var.redis_sg_rules[count.index].protocol
}
resource "aws_security_group_rule" "redis_rule1" {
  from_port                = var.redis_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = aws_security_group.ecs_tasks.id
  to_port                  = var.redis_port
  type                     = "ingress"
  description              = "Allows inbound traffic from ECS"
}
resource "aws_security_group_rule" "ecs_rule2" {
  from_port                = var.redis_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.redis.id
  to_port                  = var.redis_port
  type                     = "egress"
  description              = "Allows outbound traffic to Redis"
}
#resource "aws_security_group_rule" "alb_rule1" {
#  from_port                = var.container_port
#  protocol                 = "tcp"
#  security_group_id        = aws_security_group.alb.id
#  source_security_group_id = aws_security_group.ecs_tasks.id
#  to_port                  = var.container_port
#  type                     = "egress"
#  description              = "Allows outbound traffic to ECS"
#}
#resource "aws_security_group_rule" "ecs_rule1" {
#  from_port                = var.container_port
#  protocol                 = "tcp"
#  security_group_id        = aws_security_group.ecs_tasks.id
#  source_security_group_id = aws_security_group.alb.id
#  to_port                  = var.container_port
#  type                     = "ingress"
#  description              = "Allows inbound traffic from ALB"
#}