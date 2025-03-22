resource "aws_s3_bucket" "cloud-fe-bucket" {
  bucket = var.bucket_name  # Referencing the variable defined in variables.tf
}

resource "aws_s3_bucket_website_configuration" "cloud-fe-bucket" {
  bucket = aws_s3_bucket.cloud-fe-bucket.id
  
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "cloud-fe-bucket" {
  bucket = aws_s3_bucket.cloud-fe-bucket.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "cloud-fe-oac" {
  name="cloud-fe-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior = "always"
  signing_protocol = "sigv4"
}

resource "aws_cloudfront_distribution" "cloud_fe_distribution" {
  origin {
    domain_name = aws_s3_bucket.cloud-fe-bucket.bucket_regional_domain_name
    origin_id   = "s3origin"

    origin_access_control_id = aws_cloudfront_origin_access_control.cloud-fe-oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
      headers = ["Origin"]
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
}


# S3 bucket policy to allow CloudFront access
data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cloud-fe-bucket.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["${aws_cloudfront_distribution.cloud_fe_distribution.arn}"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloud-fe-bucket_policy" {
  bucket = aws_s3_bucket.cloud-fe-bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}