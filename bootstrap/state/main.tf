# The S3 bucket that holds Terraform state. Built first, on its own, because
# the root configuration cannot store its state in a bucket it creates itself.
#
#   terraform -chdir=bootstrap/state init
#   terraform -chdir=bootstrap/state apply -var-file=../../terraform.tfvars
#
# Notes: notes/state/01-remote-state.md

terraform {
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "cognify-ops-tfstate-2ca21da7"
    key          = "bootstrap/state/terraform.tfstate"
    region       = "ap-southeast-2"
    profile      = "swop"
    encrypt      = true
    use_lockfile = true
  }
}

variable "aws_account_id" {
  description = "12-digit ID of the AWS account to deploy into."
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use."
  type        = string
  default     = "swop"
}

provider "aws" {
  region              = "ap-southeast-2"
  profile             = var.aws_profile
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project    = "cognify"
      ManagedBy  = "terraform"
      Repository = "cognify-ops-cloud-infra-terraform-"
      Purpose    = "terraform-state"
    }
  }
}

resource "aws_s3_bucket" "state" {
  bucket = "cognify-ops-tfstate-2ca21da7"

  # Losing this bucket means losing track of everything Terraform built.
  lifecycle {
    prevent_destroy = true
  }
}

# Keeps every old version of the state file, so a bad apply can be undone.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Old versions are only useful for a while. Without this they pile up forever.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket     = aws_s3_bucket.state.id
  depends_on = [aws_s3_bucket_versioning.state]

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "state" {
  bucket     = aws_s3_bucket.state.id
  depends_on = [aws_s3_bucket_public_access_block.state]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.state.arn,
        "${aws_s3_bucket.state.arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}

output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}
