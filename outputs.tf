output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_cidrs" {
  value = module.network.subnet_cidrs
}

output "server_public_ip" {
  description = "Elastic IP of the server."
  value       = module.server.public_ip
}

output "server_instance_id" {
  value = module.server.instance_id
}

output "api_url" {
  description = "Base URL of the API."
  value       = "http://${module.server.public_ip}/api"
}

output "ssh_command" {
  value = "ssh ubuntu@${module.server.public_ip}"
}

output "sqs_queue_url" {
  description = "Goes into the server's .env as SQS_QUEUE_URL."
  value       = module.embedding_queue.url
}
