output "aws_connection" {
  description = "Verified account and region used by this Terraform configuration."
  value = {
    account_id = data.aws_caller_identity.current.account_id
    region     = data.aws_region.current.region
  }
}

output "network" {
  description = "Network module outputs for the application modules."
  value = {
    vpc_id          = module.network.vpc_id
    subnets         = module.network.subnets
    nat_gateway_ids = module.network.nat_gateway_ids
  }
}

output "database" {
  description = "RDS metadata without credentials."
  value       = module.database.connection
}

output "shared_content" {
  description = "EFS metadata for shared WordPress content."
  value       = module.storage.file_system
}

output "application" {
  description = "ASG and application secret metadata only; no secret values."
  value = {
    autoscaling_group_name = module.compute.autoscaling_group_name
    instance_role_arn      = module.compute.instance_role_arn
    application_secret_arn = module.initialization.application_secret_arn
  }
}

output "website" {
  description = "Planned public endpoint and CloudFront metadata; not a runtime success claim."
  value = {
    url          = var.site_url
    distribution = module.cdn.distribution
    origin_dns   = var.origin_domain_name
    alb_dns_name = module.load_balancer.dns_name
  }
}

output "certificate_dns_validation" {
  description = "ACM validation CNAMEs to publish in external DNS when hosted_zone_id is null."
  value       = module.certificates.dns_validation_records
}
