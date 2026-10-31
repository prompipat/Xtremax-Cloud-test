mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["ap-southeast-2a", "ap-southeast-2b"] }
  }
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:ap-southeast-2:123456789012:certificate/01234567-89ab-cdef-0123-456789abcdef"
      domain_validation_options = [{
        domain_name          = "origin.example.com", resource_record_name = "_origin.origin.example.com.",
        resource_record_type = "CNAME", resource_record_value = "_origin.acm-validations.aws."
      }]
    }
  }
}

mock_provider "random" {}

mock_provider "aws" {
  alias = "us_east_1"
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/11234567-89ab-cdef-0123-456789abcdef"
      domain_validation_options = [{
        domain_name          = "school.example.com", resource_record_name = "_viewer.school.example.com.",
        resource_record_type = "CNAME", resource_record_value = "_viewer.acm-validations.aws."
      }]
    }
  }
}

variables {
  aws_account_id     = "123456789012"
  site_url           = "https://school.example.com"
  origin_domain_name = "origin.example.com"
}

run "external_dns_certificates" {
  command   = plan
  providers = { aws = aws, aws.us_east_1 = aws.us_east_1 }

  assert {
    condition = (
      module.certificates.managed_validation_record_count == 0
    )
    error_message = "The external-DNS root configuration must plan without Terraform-managed validation records."
  }
  assert {
    condition     = length(aws_route53_record.origin) == 0 && length(aws_route53_record.site) == 0
    error_message = "External DNS mode must not create Route 53 records."
  }
}

run "route53_dns_certificates" {
  command   = plan
  providers = { aws = aws, aws.us_east_1 = aws.us_east_1 }
  variables { hosted_zone_id = "Z0123456789EXAMPLE" }

  assert {
    condition = (
      module.certificates.managed_validation_record_count == 2 &&
      length(aws_route53_record.origin) == 1 && length(aws_route53_record.site) == 2
    )
    error_message = "Route 53 mode must create both ACM validation records."
  }
}
