terraform {
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Created by bootstrap/state. Notes: notes/state/01-remote-state.md
  backend "s3" {
    bucket       = "cognify-ops-tfstate-2ca21da7"
    key          = "prod/terraform.tfstate"
    region       = "ap-southeast-2"
    profile      = "swop"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region  = "ap-southeast-2"
  profile = var.aws_profile

  # Refuse to run against any account other than the one in terraform.tfvars.
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

# VPC, subnets, internet gateway, public route table.
# Notes: notes/network/01-cidr-plan.md, notes/network/02-internet-access.md
module "network" {
  source = "./modules/network"

  project     = "cognify"
  environment = "prod"
  vpc_cidr    = "10.30.0.0/16"

  availability_zones = ["ap-southeast-2a", "ap-southeast-2b"]
}

# The API hands embedding jobs to the worker through this queue.
module "embedding_queue" {
  source = "./modules/queue"

  name = "embedding-jobs"
}

# The EC2 instance that runs the API, the embedding worker and Postgres.
# Notes: notes/compute/01-server.md
module "server" {
  source = "./modules/server"

  project     = "cognify"
  environment = "prod"
  vpc_id      = module.network.vpc_id
  subnet_id   = module.network.public_subnet_ids[0]

  # 1 GB of memory is enough because images are built on a laptop, not here.
  instance_type  = "t4g.micro"
  volume_size_gb = 16

  ssh_public_key    = var.ssh_public_key
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
  queue_arns        = [module.embedding_queue.arn]
}
