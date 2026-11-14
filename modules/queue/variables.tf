variable "name" {
  description = "Queue name. The dead-letter queue is named <name>-dlq."
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "How long a received message stays hidden from other consumers. Must be longer than the slowest job."
  type        = number
  default     = 120
}

variable "max_receive_count" {
  description = "How many times a message can be received before it moves to the dead-letter queue."
  type        = number
  default     = 3
}
