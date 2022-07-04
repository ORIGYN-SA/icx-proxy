locals {
  lb_default_sg_rules = [{
    type        = "ingress"
    protocol    = "tcp"
    from_port   = 80,
    to_port     = 80,
    cidr_blocks = ["0.0.0.0/0"]
    },
    {
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 443,
      to_port     = 443,
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      type        = "egress"
      protocol    = "-1"
      from_port   = 0,
      to_port     = 0,
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  ecs_default_sg_rules = [{
    type        = "egress"
    protocol    = "-1"
    from_port   = 0,
    to_port     = 0,
    cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  redis_default_sg_rules = [{
    type        = "egress"
    protocol    = "-1"
    from_port   = 0,
    to_port     = 0,
    cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}