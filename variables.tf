variable "aws_account_id" {
  description = "12-digit ID of the AWS account to deploy into. Terraform refuses to run against any other account."
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use."
  type        = string
  default     = "swop"
}
