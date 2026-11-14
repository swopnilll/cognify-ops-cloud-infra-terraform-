output "public_ip" {
  description = "Elastic IP of the server. Point your domain's A record here."
  value       = aws_eip.server.public_ip
}

output "app_url" {
  value = "http://${aws_eip.server.public_ip}"
}

output "ssh_command" {
  value = "ssh ubuntu@${aws_eip.server.public_ip}"
}

output "sqs_queue_url" {
  description = "Put this in deploy/.env.prod as SQS_QUEUE_URL."
  value       = aws_sqs_queue.embedding_jobs.url
}
