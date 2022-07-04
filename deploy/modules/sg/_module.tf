resource "aws_security_group" "alb" {
  name   = var.alb_sg_name
  vpc_id = data.aws_vpc.selected_vpc.id

  tags = merge({ Name = var.alb_sg_name }, var.tags)

}

resource "aws_security_group" "ecs_tasks" {
  name   = var.ecs_task_sg_name
  vpc_id = data.aws_vpc.selected_vpc.id

  tags = merge({ Name = var.ecs_task_sg_name }, var.tags)

}

resource "aws_security_group" "redis" {
  name   = var.redis_sg_name
  vpc_id = data.aws_vpc.selected_vpc.id

  tags = merge({ Name = var.redis_sg_name }, var.tags)

}
resource "aws_security_group_rule" "ecs_rules" {
  count = length(var.ecs_sg_rules)

  security_group_id = aws_security_group.ecs_tasks.id
  type              = var.ecs_sg_rules[count.index].type

  cidr_blocks = var.ecs_sg_rules[count.index].cidr_blocks
  from_port   = var.ecs_sg_rules[count.index].from_port
  to_port     = var.ecs_sg_rules[count.index].to_port
  protocol    = var.ecs_sg_rules[count.index].protocol
}
resource "aws_security_group_rule" "alb_rules" {
  count = length(var.lb_sg_rules)

  security_group_id = aws_security_group.alb.id
  type              = var.lb_sg_rules[count.index].type

  cidr_blocks = var.lb_sg_rules[count.index].cidr_blocks
  from_port   = var.lb_sg_rules[count.index].from_port
  to_port     = var.lb_sg_rules[count.index].to_port
  protocol    = var.lb_sg_rules[count.index].protocol
}
resource "aws_security_group_rule" "redis_rules" {
  count = length(var.redis_sg_rules)

  security_group_id = aws_security_group.redis.id
  type              = var.redis_sg_rules[count.index].type

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
}
resource "aws_security_group_rule" "ecs_rule2" {
  from_port                = var.redis_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.redis.id
  to_port                  = var.redis_port
  type                     = "egress"
}
resource "aws_security_group_rule" "alb_rule1" {
  from_port                = var.container_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.ecs_tasks.id
  to_port                  = var.container_port
  type                     = "egress"
}
resource "aws_security_group_rule" "ecs_rule1" {
  from_port                = var.container_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = aws_security_group.alb.id
  to_port                  = var.container_port
  type                     = "ingress"
}