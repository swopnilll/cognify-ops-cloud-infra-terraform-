resource "aws_s3_bucket" "cloud-fe-bucket" {
  bucket = var.bucket_name  # Referencing the variable defined in variables.tf
}
