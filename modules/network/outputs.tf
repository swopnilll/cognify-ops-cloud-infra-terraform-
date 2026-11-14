output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, in availability zone order."
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, in availability zone order."
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "subnet_cidrs" {
  description = "CIDR block of each subnet, by name. Compare with the CIDR plan."
  value = {
    public-a  = aws_subnet.public_a.cidr_block
    public-b  = aws_subnet.public_b.cidr_block
    private-a = aws_subnet.private_a.cidr_block
    private-b = aws_subnet.private_b.cidr_block
  }
}
