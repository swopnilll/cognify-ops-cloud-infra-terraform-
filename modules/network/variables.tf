variable "project" {
  description = "Project name, used in resource names."
  type        = string
}

variable "environment" {
  description = "Environment name, e.g. staging or prod."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC. Must be a /16: subnets are /24s cut from it."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && endswith(var.vpc_cidr, "/16")
    error_message = "vpc_cidr must be a valid IPv4 /16, e.g. 10.30.0.0/16."
  }
}

variable "availability_zones" {
  description = "Two availability zones to create subnets in, e.g. [\"ap-southeast-2a\", \"ap-southeast-2b\"]."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly two availability zones are required."
  }
}
