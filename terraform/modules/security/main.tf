# ── ALB Security Group ───────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Allow HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 11434
    to_port     = 11434
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidrs
    description = "Ollama API access (for Flowise on Bastion)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-alb-sg" }
}

# ── Bastion Security Group ───────────────────────────────────
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Allow SSH only from SoftServe IP ranges"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidrs
  }

 ingress {
  from_port   = 3000
  to_port     = 3000
  protocol    = "tcp"
  cidr_blocks = var.bastion_allowed_cidrs
  description = "Flowise Web UI access"
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-bastion-sg" }
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
    description     = "PostgreSQL from Bastion (Flowise Web UI)"
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

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}-${var.environment}-bastion-profile"
  role = aws_iam_role.bastion.name
}
