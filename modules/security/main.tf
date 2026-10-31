data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "tier" {
  for_each = toset(["alb", "application", "database", "efs"])

  name_prefix = "${var.name}-${each.key}-"
  description = "Dedicated ${each.key} security group; rules managed separately"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-${each.key}" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "cloudfront_alb" {
  security_group_id = aws_security_group.tier["alb"].id
  description       = "HTTPS from CloudFront origin-facing servers"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

locals {
  connections = {
    alb_application = { source = "alb", destination = "application", port = 80 }
    application_db  = { source = "application", destination = "database", port = 3306 }
    application_efs = { source = "application", destination = "efs", port = 2049 }
  }
}

resource "aws_vpc_security_group_ingress_rule" "internal" {
  for_each = local.connections

  security_group_id            = aws_security_group.tier[each.value.destination].id
  referenced_security_group_id = aws_security_group.tier[each.value.source].id
  description                  = each.key
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "internal" {
  for_each = local.connections

  security_group_id            = aws_security_group.tier[each.value.source].id
  referenced_security_group_id = aws_security_group.tier[each.value.destination].id
  description                  = each.key
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "application_https" {
  security_group_id = aws_security_group.tier["application"].id
  description       = "HTTPS bootstrap and AWS APIs through NAT"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
