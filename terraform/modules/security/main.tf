# ── ALB Security Group ───────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Allow HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-alb-sg" }
}

resource "aws_security_group_rule" "alb_http_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP from internet"
}

resource "aws_security_group_rule" "alb_https_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS from internet"
}

resource "aws_security_group_rule" "alb_anythingllm_3000" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "AnythingLLM Web UI via ALB"
}

resource "aws_security_group_rule" "alb_grafana_3001" {
  type              = "ingress"
  from_port         = 3001
  to_port           = 3001
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Grafana via ALB"
}

resource "aws_security_group_rule" "alb_from_bastion_11434" {
  type                     = "ingress"
  from_port                = 11434
  to_port                  = 11434
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.bastion.id
  description               = "Ollama API from Bastion only (AnythingLLM)"
}

# ── Bastion Security Group ───────────────────────────────────
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Allow SSH only from SoftServe IP ranges"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-bastion-sg" }
}

# SSH ingress (port 22) rule exists in AWS but is intentionally left
# unmanaged by Terraform due to an import ID format mismatch with the
# classic aws_security_group_rule resource for multi-CIDR rules.
# Rule verified working — do not delete manually.

resource "aws_security_group_rule" "bastion_from_alb_3000" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion.id
  source_security_group_id = aws_security_group.alb.id
  description               = "AnythingLLM Web UI via ALB"
}

resource "aws_security_group_rule" "bastion_from_alb_3001" {
  type                     = "ingress"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion.id
  source_security_group_id = aws_security_group.alb.id
  description               = "Grafana via ALB"
}

resource "aws_security_group_rule" "bastion_from_asg_9090" {
  type                     = "ingress"
  from_port                = 9090
  to_port                  = 9090
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion.id
  source_security_group_id = aws_security_group.asg.id
  description               = "Prometheus remote_write from LLM instances (Grafana Agent)"
}

# ── ASG Security Group ───────────────────────────────────────
resource "aws_security_group" "asg" {
  name        = "${var.project_name}-${var.environment}-asg-sg"
  description = "Allow traffic from ALB and Bastion only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 11434
    to_port         = 11434
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Ollama API from ALB"
  }
  ingress {
    from_port       = 11434
    to_port         = 11434
    protocol        = "tcp"
    security_groups = [aws_security_group.ollama_internal_alb.id]
    description     = "Ollama API from internal ALB health checks"
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "SSH from Bastion only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-asg-sg" }
}

# Security Group for internal Ollama ALB — allows health checks to ASG instances
resource "aws_security_group" "ollama_internal_alb" {
  name        = "${var.project_name}-${var.environment}-ollama-int-alb-sg"
  description = "Internal ALB for Ollama - VPC only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 11434
    to_port         = 11434
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "Ollama API from Bastion (AnythingLLM)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-ollama-int-alb-sg" }
}

# ── RDS Security Group ───────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Allow PostgreSQL from ASG only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.asg.id]
    description     = "PostgreSQL from ASG instances only"
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "PostgreSQL from Bastion (AnythingLLM Web UI)"
  }

  tags = { Name = "${var.project_name}-${var.environment}-rds-sg" }
}

resource "aws_iam_role" "bastion" {
  name = "${var.project_name}-${var.environment}-bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "bastion_ssm" {
  name = "${var.project_name}-${var.environment}-bastion-ssm-policy"
  role = aws_iam_role.bastion.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = "arn:aws:ssm:*:*:parameter/${var.project_name}/*"
    }]
  })
}

# SSM Session Manager access for Bastion (in addition to existing GetParameter policy)
resource "aws_iam_role_policy_attachment" "bastion_ssm_core" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}-${var.environment}-bastion-profile"
  role = aws_iam_role.bastion.name
}

# ── IAM for ASG instances ─────────────────────────────────────
resource "aws_iam_role" "asg" {
  name = "${var.project_name}-${var.environment}-asg-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# AWS managed policy covers all SSM requirements (maintained by AWS)
resource "aws_iam_role_policy_attachment" "asg_ssm" {
  role       = aws_iam_role.asg.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# AWS managed policy allows the CloudWatch Agent to publish custom metrics
# (memory, disk) that AWS doesn't collect natively for EC2
resource "aws_iam_role_policy_attachment" "asg_cloudwatch" {
  role       = aws_iam_role.asg.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "asg" {
  name = "${var.project_name}-${var.environment}-asg-profile"
  role = aws_iam_role.asg.name
}