data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

module "network" {
  source = "./modules/network"

  name               = "xtremax-wordpress"
  vpc_cidr           = var.vpc_cidr
  availability_zones = slice(sort(data.aws_availability_zones.available.names), 0, 2)
  single_nat_gateway = var.single_nat_gateway
}

module "security" {
  source = "./modules/security"

  name   = "xtremax-wordpress"
  vpc_id = module.network.vpc_id
}

module "database" {
  source = "./modules/database"

  name                      = "xtremax-wordpress"
  subnet_ids                = [for subnet in module.network.subnets.database : subnet.id]
  security_group_id         = module.security.security_group_ids.database
  engine_version            = var.db_engine_version
  instance_class            = var.db_instance_class
  multi_az                  = var.db_multi_az
  deletion_protection       = var.db_deletion_protection
  final_snapshot_identifier = var.db_final_snapshot_identifier
}

module "storage" {
  source = "./modules/storage"

  name              = "xtremax-wordpress"
  subnet_ids        = { for zone, subnet in module.network.subnets.application : zone => subnet.id }
  security_group_id = module.security.security_group_ids.efs
}

module "initialization" {
  source = "./modules/initialization"

  name              = "xtremax-wordpress"
  subnet_ids        = [for subnet in module.network.subnets.application : subnet.id]
  security_group_id = module.security.security_group_ids.application
  db_address        = module.database.connection.address
  master_secret_arn = module.database.connection.master_secret_arn
  package_file      = abspath("${path.root}/artifacts/db-initializer.zip")

  # NAT routes, NACLs and SG rules must exist before the private initializer runs.
  depends_on = [module.network, module.security]
}

module "compute" {
  source = "./modules/compute"

  name                   = "xtremax-wordpress"
  ami_id                 = var.wordpress_ami_id
  instance_type          = var.wordpress_instance_type
  subnet_ids             = [for subnet in module.network.subnets.application : subnet.id]
  security_group_id      = module.security.security_group_ids.application
  application_secret_arn = module.initialization.application_secret_arn
  db_address             = module.database.connection.address
  efs                    = module.storage.file_system
  downloads              = jsondecode(file("${path.root}/assets/downloads.json"))
  site_url               = var.site_url
  admin_email            = var.site_admin_email
  desired_capacity       = var.wordpress_desired_capacity
  target_group_arns      = [module.load_balancer.target_group_arn]

  depends_on = [module.initialization, module.storage]
}

locals {
  site_domain_name = trimprefix(var.site_url, "https://")
}

resource "random_password" "origin_header" {
  length  = 48
  special = false
}

module "certificates" {
  source = "./modules/certificates"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
  name               = "xtremax-wordpress"
  site_domain_name   = local.site_domain_name
  origin_domain_name = var.origin_domain_name
  hosted_zone_id     = var.hosted_zone_id
}

module "load_balancer" {
  source = "./modules/load_balancer"

  name                = "xtremax-wordpress"
  vpc_id              = module.network.vpc_id
  subnet_ids          = [for subnet in module.network.subnets.public : subnet.id]
  security_group_id   = module.security.security_group_ids.alb
  certificate_arn     = module.certificates.origin_certificate_arn
  origin_header_value = random_password.origin_header.result
}

module "cdn" {
  source = "./modules/cdn"

  name                   = "xtremax-wordpress"
  site_domain_name       = local.site_domain_name
  origin_domain_name     = var.origin_domain_name
  viewer_certificate_arn = module.certificates.viewer_certificate_arn
  origin_header_value    = random_password.origin_header.result

  depends_on = [module.load_balancer, aws_route53_record.origin]
}

resource "aws_route53_record" "origin" {
  count   = var.hosted_zone_id == null ? 0 : 1
  zone_id = var.hosted_zone_id
  name    = var.origin_domain_name
  type    = "A"
  alias {
    name                   = module.load_balancer.dns_name
    zone_id                = module.load_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "site" {
  for_each = var.hosted_zone_id == null ? toset([]) : toset(["A", "AAAA"])
  zone_id  = var.hosted_zone_id
  name     = local.site_domain_name
  type     = each.value
  alias {
    name                   = module.cdn.distribution.domain_name
    zone_id                = module.cdn.distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
