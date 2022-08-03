resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.app_name_prefix}-redis-subnet-${var.environment}"
  subnet_ids = data.aws_subnets.private_subnets.ids

  tags = merge({ Name = "${var.app_name_prefix}-redis-subnet-${var.environment}" }, var.tags)

}

resource "aws_elasticache_replication_group" "redis_replication_group" {
  #bridgecrew:skip=CKV_AWS_30: "Ensure all data stored in the Elasticache Replication Group is securely encrypted at transit"
  #bridgecrew:skip=CKV_AWS_191: "Ensure Elasticache replication group is encrypted by KMS using a customer managed Key (CMK)"
  #bridgecrew:skip=CKV_AWS_29: "Ensure all data stored in the Elasticache Replication Group is securely encrypted at rest"
  #bridgecrew:skip=CKV_AWS_31: "Ensure all data stored in the Elasticache Replication Group is securely encrypted at transit and has auth token"
  replication_group_id       = var.redis_cluster
  automatic_failover_enabled = true
  engine                     = "redis"
  node_type                  = var.node_type
  parameter_group_name       = var.parameter_group_name
  engine_version             = var.engine_version
  num_cache_clusters         = var.num_cache_nodes
  port                       = var.redis_port
  maintenance_window         = var.maintenance_window
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.auth_token
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  kms_key_id                 = var.kms_key_enable ? data.aws_kms_key.key[0].id : null
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [data.aws_security_group.redis.id]
  description                = "Replication group for ${var.redis_cluster}"
  tags                       = merge({ Name = var.redis_cluster }, var.tags)
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
  user_group_id = "${var.app_name_prefix}-redis-users-${var.environment}"
  user_ids      = [aws_elasticache_user.redis_user.user_id, "default"]
  tags          = merge({ Name = "${var.app_name_prefix}-redis-users-${var.environment}" }, var.tags)
}