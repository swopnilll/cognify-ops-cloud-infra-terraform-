# Cognify Ops, lean edition: everything on one EC2 instance in a public subnet.
# No NAT gateway, no load balancer, no RDS.

# ---------------------------------------------------------------- network ---

resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "cognify" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "cognify" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "cognify-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "cognify-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "server" {
  name        = "cognify-server"
  description = "Web traffic from anywhere, SSH from one address"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "cognify-server" }
}

# ------------------------------------------------------------------ queue ---

resource "aws_sqs_queue" "embedding_jobs_dlq" {
  name                      = "embedding-jobs-dlq"
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_sqs_queue" "embedding_jobs" {
  name                       = "embedding-jobs"
  visibility_timeout_seconds = 120
  receive_wait_time_seconds  = 20

  # After 3 failed attempts a message moves to the dead-letter queue.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.embedding_jobs_dlq.arn
    maxReceiveCount     = 3
  })
}

# -------------------------------------------------------------------- IAM ---
# The instance role gives the containers SQS access without any stored keys.

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "server" {
  name               = "cognify-server"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "sqs_access" {
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.embedding_jobs.arn]
  }
}

resource "aws_iam_role_policy" "sqs_access" {
  name   = "embedding-queue-access"
  role   = aws_iam_role.server.id
  policy = data.aws_iam_policy_document.sqs_access.json
}

# Lets you open a shell from the console (Session Manager) if SSH is unavailable.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "server" {
  name = "cognify-server"
  role = aws_iam_role.server.name
}

# ----------------------------------------------------------------- server ---

data "aws_ssm_parameter" "ubuntu_arm64" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "deploy" {
  key_name   = "cognify-deploy"
  public_key = var.ssh_public_key
}

resource "aws_instance" "server" {
  ami                    = data.aws_ssm_parameter.ubuntu_arm64.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.server.id]
  key_name               = aws_key_pair.deploy.key_name
  iam_instance_profile   = aws_iam_instance_profile.server.name
  user_data              = file("${path.module}/user_data.sh")

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size_gb
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
    # Containers sit one network hop behind the host; 2 lets them reach the
    # metadata service to pick up the instance role.
    http_put_response_hop_limit = 2
  }

  lifecycle {
    # A newer Ubuntu image or an edited bootstrap script must not replace the
    # server: the database lives on its disk.
    ignore_changes = [ami, user_data]
  }

  tags = { Name = "cognify-server" }
}

# Fixed public address that survives stop/start.
resource "aws_eip" "server" {
  instance = aws_instance.server.id
  domain   = "vpc"
  tags     = { Name = "cognify-server" }
}

# ----------------------------------------------------------------- budget ---

resource "aws_budgets_budget" "monthly" {
  name         = "cognify-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}
