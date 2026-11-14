variable "aws_account_id" {
  description = "12-digit ID of the AWS account to deploy into. Terraform refuses to run against any other account."
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use."
  type        = string
  default     = "swop"
}

variable "ssh_public_key" {
  description = "Contents of your SSH public key, e.g. ~/.ssh/id_ed25519.pub."
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH to the server, e.g. [\"203.0.113.7/32\"]. Find yours with: curl -s https://checkip.amazonaws.com"
  type        = list(string)
  default     = []
}

variable "budget_email" {
  description = "Email address for budget alerts."
  type        = string
}
