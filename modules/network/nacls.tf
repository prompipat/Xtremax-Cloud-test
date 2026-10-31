# NACLs are stateless. Return traffic needs explicit ephemeral-port rules.
# Public subnets also host NAT, so HTTPS and ephemeral rules must cover the
# application bootstrap path. Workload SGs provide the narrower identity rules.
locals {
  tier_cidrs = {
    for tier in ["public", "application", "database"] : tier => [
      for zone in var.availability_zones : local.subnets["${tier}-${zone}"].cidr
    ]
  }
  acl_rules = merge(
    {
      public_in_https        = { tier = "public", egress = false, number = 100, from = 443, to = 443, cidr = "0.0.0.0/0" }
      public_in_return       = { tier = "public", egress = false, number = 110, from = 1024, to = 65535, cidr = "0.0.0.0/0" }
      public_out_https       = { tier = "public", egress = true, number = 100, from = 443, to = 443, cidr = "0.0.0.0/0" }
      public_out_return      = { tier = "public", egress = true, number = 110, from = 1024, to = 65535, cidr = "0.0.0.0/0" }
      application_in_return  = { tier = "application", egress = false, number = 100, from = 1024, to = 65535, cidr = "0.0.0.0/0" }
      application_out_https  = { tier = "application", egress = true, number = 100, from = 443, to = 443, cidr = "0.0.0.0/0" }
      application_out_return = { tier = "application", egress = true, number = 110, from = 1024, to = 65535, cidr = var.vpc_cidr }
    },
    { for index, cidr in local.tier_cidrs.public : "application_in_http_${index}" => {
      tier = "application", egress = false, number = 200 + index, from = 80, to = 80, cidr = cidr
    } },
    { for index, cidr in local.tier_cidrs.application : "public_out_http_${index}" => {
      tier = "public", egress = true, number = 200 + index, from = 80, to = 80, cidr = cidr
    } },
    { for index, cidr in local.tier_cidrs.application : "application_in_nfs_${index}" => {
      tier = "application", egress = false, number = 300 + index, from = 2049, to = 2049, cidr = cidr
    } },
    { for index, cidr in local.tier_cidrs.application : "application_out_nfs_${index}" => {
      tier = "application", egress = true, number = 300 + index, from = 2049, to = 2049, cidr = cidr
    } },
    { for index, cidr in local.tier_cidrs.database : "application_out_mysql_${index}" => {
      tier = "application", egress = true, number = 400 + index, from = 3306, to = 3306, cidr = cidr
    } },
    { for index, cidr in local.tier_cidrs.application : "database_in_mysql_${index}" => {
      tier = "database", egress = false, number = 100 + index, from = 3306, to = 3306, cidr = cidr
    } },
    { for index, cidr in local.tier_cidrs.application : "database_out_return_${index}" => {
      tier = "database", egress = true, number = 100 + index, from = 1024, to = 65535, cidr = cidr
    } }
  )
}

resource "aws_network_acl" "tier" {
  for_each = toset(["public", "application", "database"])
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${var.name}-${each.key}", Tier = each.key }
}

resource "aws_network_acl_association" "this" {
  for_each = local.subnets

  subnet_id      = aws_subnet.this[each.key].id
  network_acl_id = aws_network_acl.tier[each.value.tier].id
}

resource "aws_network_acl_rule" "this" {
  for_each = local.acl_rules

  network_acl_id = aws_network_acl.tier[each.value.tier].id
  rule_number    = each.value.number
  egress         = each.value.egress
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.from
  to_port        = each.value.to
}
