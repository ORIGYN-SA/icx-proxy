locals {
  lb_default_sg_rules = [{
    type        = "ingress"
    protocol    = "tcp"
    from_port   = 80,
    to_port     = 80,
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allows inbound HTTP access from any IPv4 address"
    },
    {
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 443,
      to_port     = 443,
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allows inbound HTTPS access from any IPv4 address"
    },
    {
      type        = "egress"
      protocol    = "-1"
      from_port   = 0,
      to_port     = 0,
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allows outbound traffic to any IPv4 address"
    }
  ]
  ecs_default_sg_rules = [{
    type        = "egress"
    protocol    = "-1"
    from_port   = 0,
    to_port     = 0,
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allows outbound traffic to any IPv4 address"
    },
    {
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 443,
      to_port     = 443,
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allows inbound HTTPS access from any IPv4 address"
    },
    {
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 5000,
      to_port     = 5000,
      cidr_blocks = ["10.0.0.0/16"]
      description = "Allows inbound traffic from NLB"
    },
  ]
  redis_default_sg_rules = [{
    type        = "egress"
    protocol    = "-1"
    from_port   = 0,
    to_port     = 0,
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allows outbound traffic to any IPv4 address"
    }
  ]
}