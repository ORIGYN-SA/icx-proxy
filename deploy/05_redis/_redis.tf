resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name_prefix}-redis-subnet-${var.environment}"
  subnet_ids = data.aws_subnets.private_subnets.ids

  tags = {
    Name = "${local.name_prefix}-redis-subnet-${var.environment}"
  }
}

resource "aws_elasticache_replication_group" "redis_replication_group" {
  replication_group_id        = local.redis_cluster
  automatic_failover_enabled  = true
  engine                      = "redis"
  node_type                   = var.node_type
  parameter_group_name        = var.parameter_group_name
  engine_version              = var.engine_version
  num_cache_clusters          = var.num_cache_nodes
  port                        = var.redis_port
  maintenance_window          = var.maintenance_window
  subnet_group_name           = aws_elasticache_subnet_group.redis.name
  security_group_ids          = [data.aws_security_group.redis.id]
  description                 = "Replication group for ${local.redis_cluster}"
  tags = {
    Name = local.redis_cluster
  }
}

resource "aws_elasticache_user" "redis_user" {
  user_id       = data.aws_ssm_parameter.db_username.value
  user_name     = data.aws_ssm_parameter.db_username.value
  access_string = "on ~app::* -@all +@read +@hash +@bitmap +@geo -setbit -bitfield -hset -hsetnx -hmset -hincrby -hincrbyfloat -hdel -bitop -geoadd -georadius -georadiusbymember"
  engine        = "REDIS"
  passwords     = [data.aws_ssm_parameter.db_password.value]
}
resource "aws_elasticache_user_group" "redis_user_group" {
  engine        = "REDIS"
  user_group_id = "${local.name_prefix}-redis-users-${var.environment}"
  user_ids      = [aws_elasticache_user.redis_user.user_id, "default"]
}