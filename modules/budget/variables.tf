variable "name" {
  description = "Budget name."
  type        = string
}

variable "limit_usd" {
  description = "Monthly cost limit in US dollars."
  type        = number
}

variable "email" {
  description = "Address that receives the alerts."
  type        = string
}
