locals {
  zones = { for index, zone in var.availability_zones : zone => index }
  subnets = merge([
    for tier_index, tier in ["public", "application", "database"] : {
      for zone, zone_index in local.zones : "${tier}-${zone}" => {
        tier = tier
        zone = zone
        cidr = cidrsubnet(var.vpc_cidr, 8, tier_index * 2 + zone_index)
      }
    }
  ]...)
  nat_zones = var.single_nat_gateway ? { (var.availability_zones[0]) = 0 } : local.zones
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}

resource "aws_default_security_group" "this" {
  vpc_id  = aws_vpc.this.id
  ingress = []
  egress  = []
  tags    = { Name = "${var.name}-unused-default" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.zone
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.name}-${each.key}"
    Tier = each.value.tier
  }
}

resource "aws_eip" "nat" {
  for_each = local.nat_zones
  domain   = "vpc"
  tags     = { Name = "${var.name}-nat-${each.key}" }
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_zones

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.this["public-${each.key}"].id
  tags          = { Name = "${var.name}-nat-${each.key}" }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table" "application" {
  for_each = local.zones
  vpc_id   = aws_vpc.this.id
  tags     = { Name = "${var.name}-application-${each.key}" }
}

resource "aws_route" "application_internet" {
  for_each = local.zones

  route_table_id         = aws_route_table.application[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? var.availability_zones[0] : each.key].id
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-database-isolated" }
  # No internet default route; only the automatic VPC-local route.
}

resource "aws_route_table_association" "this" {
  for_each = local.subnets

  subnet_id = aws_subnet.this[each.key].id
  route_table_id = (
    each.value.tier == "public" ? aws_route_table.public.id :
    each.value.tier == "application" ? aws_route_table.application[each.value.zone].id :
    aws_route_table.database.id
  )
}
