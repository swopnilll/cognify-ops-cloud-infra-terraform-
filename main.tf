terraform {
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State is local for now. The S3 backend comes in a later step
  # (bootstrap/state), once the AWS account exists.
}

provider "aws" {
  region  = "ap-southeast-2"
  profile = var.aws_profile

  # Refuse to run against any account other than the one in terraform.tfvars.
  # The default CLI profile on this machine is a work account.
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project     = "cognify"
      Environment = "prod"
      ManagedBy   = "terraform"
      Repository  = "cognify-ops-cloud-infra-terraform-"
    }
  }
}

# CIDR plan: notes/network/01-cidr-plan.md
module "network" {
  source = "./modules/network"

  project     = "cognify"
  environment = "prod"
  vpc_cidr    = "10.30.0.0/16"

  availability_zones = ["ap-southeast-2a", "ap-southeast-2b"]
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_cidrs" {
  value = module.network.subnet_cidrs
}
