output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Elastic IP of the server."
  value       = aws_eip.this.public_ip
}

output "public_dns" {
  description = "Public DNS name of the Elastic IP."
  value       = aws_eip.this.public_dns
}

output "security_group_id" {
  description = "ID of the server's security group."
  value       = aws_security_group.this.id
}

output "role_name" {
  description = "Name of the instance's IAM role."
  value       = aws_iam_role.this.name
}
