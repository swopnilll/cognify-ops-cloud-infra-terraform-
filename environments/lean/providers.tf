terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  # Refuse to run against any account other than the one you intend.
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project   = "cognify-ops"
      ManagedBy = "terraform"
    }
  }
}
