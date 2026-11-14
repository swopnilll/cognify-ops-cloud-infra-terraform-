variable "project" {
  description = "Project name, used in resource names."
  type        = string
}

variable "environment" {
  description = "Environment name, e.g. staging or prod."
  type        = string
}

variable "vpc_id" {
  description = "VPC the security group belongs to."
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch the instance in. Must be a public subnet."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. Must be ARM (Graviton), because the AMI is arm64."
  type        = string
  default     = "t4g.small"
}

variable "volume_size_gb" {
  description = "Root volume size. Holds the OS, Docker images and the Postgres data."
  type        = number
  default     = 30
}

variable "ssh_public_key" {
  description = "SSH public key installed for the ubuntu user."
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to reach port 22, e.g. [\"203.0.113.7/32\"]. Empty closes SSH; Session Manager still works."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.ssh_allowed_cidrs, "0.0.0.0/0")
    error_message = "SSH must not be open to the whole internet."
  }
}

variable "queue_arns" {
  description = "SQS queues the instance may send to and receive from."
  type        = list(string)
}
