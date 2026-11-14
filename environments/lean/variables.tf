variable "aws_account_id" {
  description = "12-digit ID of the AWS account to deploy into. Terraform refuses to run against any other account."
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use (e.g. \"cognify\")."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "ap-southeast-2"
}

variable "instance_type" {
  description = "EC2 instance type. Must be ARM (Graviton). t4g.small = 2 vCPU / 2 GB."
  type        = string
  default     = "t4g.small"
}

variable "volume_size_gb" {
  description = "Root volume size. Holds the OS, Docker images and the Postgres data."
  type        = number
  default     = 30
}

variable "ssh_public_key" {
  description = "Contents of your SSH public key (e.g. ~/.ssh/id_ed25519.pub)."
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH in, e.g. \"203.0.113.7/32\" for your own IP."
  type        = string
}

variable "budget_limit_usd" {
  description = "Monthly budget. You get an email at 80% actual and 100% forecast spend."
  type        = number
  default     = 30
}

variable "budget_email" {
  description = "Email address for budget alerts."
  type        = string
}
