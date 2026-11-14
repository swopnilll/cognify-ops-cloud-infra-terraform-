# One EC2 instance that runs the whole backend with Docker Compose.
# Notes: notes/compute/01-server.md

locals {
  name = "${var.project}-${var.environment}-server"
}

# ---------------------------------------------------------- security group
# The instance's firewall. Rules are separate resources so each can be added
# or removed on its own.

resource "aws_security_group" "this" {
  name        = local.name
  description = "Web traffic from anywhere, SSH from named addresses only"
  vpc_id      = var.vpc_id

  tags = {
    Name = local.name
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.this.id
  description       = "HTTP from anywhere"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.this.id
  description       = "HTTPS from anywhere"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.ssh_allowed_cidrs)

  security_group_id = aws_security_group.this.id
  description       = "SSH from ${each.value}"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

# Outbound: package installs, Docker image pulls, SQS and OpenAI all need it.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --------------------------------------------------------------------- IAM
# The instance role. Containers get temporary credentials from it through the
# instance metadata service, so no access keys are stored on the server.

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = local.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# Least privilege: only these four actions, only on the named queues.
data "aws_iam_policy_document" "queues" {
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = var.queue_arns
  }
}

resource "aws_iam_role_policy" "queues" {
  name   = "queue-access"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.queues.json
}

# Session Manager: a shell from the AWS console or CLI without SSH.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# An instance profile is the wrapper that attaches a role to an instance.
resource "aws_iam_instance_profile" "this" {
  name = local.name
  role = aws_iam_role.this.name
}

# ---------------------------------------------------------------- instance

# Canonical publishes the current Ubuntu AMI ID in a public SSM parameter.
data "aws_ssm_parameter" "ubuntu_arm64" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "this" {
  key_name   = local.name
  public_key = var.ssh_public_key
}

resource "aws_instance" "this" {
  ami                    = data.aws_ssm_parameter.ubuntu_arm64.insecure_value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = aws_key_pair.this.key_name
  iam_instance_profile   = aws_iam_instance_profile.this.name
  user_data              = file("${path.module}/user_data.sh")

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size_gb
    encrypted   = true
  }

  # T4g instances launch in "unlimited" mode, which bills extra for sustained
  # high CPU. "standard" slows the instance down instead: no surprise charges.
  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
    # Containers sit one network hop behind the host. 2 lets them reach the
    # metadata service and pick up the instance role.
    http_put_response_hop_limit = 2
  }

  lifecycle {
    # A newer Ubuntu image or an edited first-boot script must not replace
    # the server: the database lives on its disk.
    ignore_changes = [ami, user_data]
  }

  tags = {
    Name = local.name
  }
}

# A fixed public address. Without it the address changes on every stop/start.
resource "aws_eip" "this" {
  instance = aws_instance.this.id
  domain   = "vpc"

  tags = {
    Name = local.name
  }
}
