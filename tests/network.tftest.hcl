# Mock AWS calls: these tests never create resources or require credentials.
mock_provider "aws" {
  override_during = plan
}

run "two_az_network" {
  command = apply

  module {
    source = "./modules/network"
  }

  variables {
    name               = "network-test"
    availability_zones = ["ap-southeast-2a", "ap-southeast-2b"]
  }

  assert {
    condition     = length(aws_subnet.this) == 6 && length(aws_nat_gateway.this) == 2
    error_message = "The default topology must have six subnets and two NAT gateways."
  }

  assert {
    condition     = alltrue([for subnet in aws_subnet.this : subnet.map_public_ip_on_launch == false])
    error_message = "Subnets must not assign public IP addresses automatically."
  }

  assert {
    condition     = length(distinct([for subnet in aws_subnet.this : subnet.cidr_block])) == 6
    error_message = "Subnet CIDRs must be distinct."
  }

  assert {
    condition     = length(aws_route_table_association.this) == 6 && length(aws_network_acl_association.this) == 6
    error_message = "Every subnet must have explicit route table and NACL associations."
  }

  assert {
    condition = alltrue([
      for key, subnet in local.subnets :
      aws_route_table_association.this[key].route_table_id == aws_route_table.database.id
      if subnet.tier == "database"
    ])
    error_message = "Database subnets must use the isolated database route table."
  }

  assert {
    condition = alltrue([
      for zone in var.availability_zones :
      aws_route.application_internet[zone].nat_gateway_id == aws_nat_gateway.this[zone].id
    ])
    error_message = "Each application subnet must route through NAT in its own AZ by default."
  }

  assert {
    condition = alltrue([
      for rule in aws_network_acl_rule.this :
      rule.from_port == 3306 && rule.to_port == 3306 && contains(local.tier_cidrs.application, rule.cidr_block)
      if rule.network_acl_id == aws_network_acl.tier["database"].id && !rule.egress
    ])
    error_message = "Database NACL ingress must permit only MySQL from application subnet CIDRs."
  }
}

run "single_nat_lab" {
  command = apply

  module {
    source = "./modules/network"
  }

  variables {
    name               = "network-test"
    availability_zones = ["ap-southeast-2a", "ap-southeast-2b"]
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Lab mode must declare exactly one NAT gateway."
  }

  assert {
    condition = alltrue([
      for route in aws_route.application_internet :
      route.nat_gateway_id == aws_nat_gateway.this["ap-southeast-2a"].id
    ])
    error_message = "Both application routes must use the shared NAT gateway in lab mode."
  }
}

run "reject_duplicate_zones" {
  command = plan

  module {
    source = "./modules/network"
  }

  variables {
    name               = "network-test"
    availability_zones = ["ap-southeast-2a", "ap-southeast-2a"]
  }

  expect_failures = [var.availability_zones]
}
