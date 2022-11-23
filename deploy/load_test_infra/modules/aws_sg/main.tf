resource "aws_security_group" "locust_master" {
  name   = var.master_name
  vpc_id = var.vpc_id
}

resource "aws_security_group" "locust_slave" {
  name   = var.slave_name
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "master_allow_nodes" {
  type                     = "ingress"
  from_port                = 5557
  to_port                  = 5557
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.locust_slave.id
  security_group_id        = aws_security_group.locust_master.id
}
resource "aws_security_group_rule" "nodes_allow_master" {
  type                     = "egress"
  from_port                = 5557
  to_port                  = 5557
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.locust_master.id
  security_group_id        = aws_security_group.locust_slave.id
}
resource "aws_security_group_rule" "nodes_allow_http_egress" {
  type              = "egress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.locust_slave.id
}
resource "aws_security_group_rule" "master_allow_http_egress" {
  type              = "egress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.locust_master.id
}
resource "aws_security_group_rule" "nodes_allow_https_egress" {
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.locust_slave.id
}
resource "aws_security_group_rule" "master_allow_https_egress" {
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.locust_master.id
}