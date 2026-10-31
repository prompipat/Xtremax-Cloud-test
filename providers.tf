provider "aws" {
  region              = var.aws_region
  profile             = var.aws_profile
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project   = "xtremax-wordpress"
      ManagedBy = "Terraform"
    }
  }
}

provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  profile             = var.aws_profile
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = { Project = "xtremax-wordpress", ManagedBy = "Terraform" }
  }
}
