# ── SSH Key Pair ─────────────────────────────────────────────
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = file(var.ssh_public_key_path)
}

# ── Bastion Host ─────────────────────────────────────────────
resource "aws_instance" "bastion" {
  ami                         = var.bastion_ami_id
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true
  tags = { Name = "bastion" }
  iam_instance_profile = var.bastion_instance_profile_name
}

# ── ALB ──────────────────────────────────────────────────────
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = { Name = "${var.project_name}-${var.environment}-alb" }
}

# ── Target Group ─────────────────────────────────────────────
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-${var.environment}-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    port                = "3000"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 25
    interval            = 30
  }

  tags = { Name = "${var.project_name}-${var.environment}-tg" }
}

# Registers bastion (where Flowise runs) as the target for the Flowise Target Group.
# Bastion is a single standalone instance (not ASG), so it needs manual attachment.
resource "aws_lb_target_group_attachment" "bastion_flowise" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.bastion.id
  port              = 3000
}

# Separate Target Group for Ollama API (port 11434) — LLM instances,
resource "aws_lb_target_group" "ollama" {
  name     = "${var.environment}-ollama-tg"
  port     = 11434
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    port                = "11434"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 25
    interval            = 30
  }

  tags = { Name = "${var.project_name}-${var.environment}-ollama-tg" }
}


# Target group for Ollama on internal ALB
resource "aws_lb_target_group" "ollama_internal" {
  name     = "${var.environment}-ollama-int-tg"
  port     = 11434
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    port                = "11434"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    interval            = 30
    timeout             = 25

  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 3600
    enabled         = true
  }

  tags = { Name = "${var.project_name}-${var.environment}-ollama-internal-tg" }
}

# ── ALB Listener ─────────────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Separate listener — routes external port 11434 traffic to Ollama Target Group.
resource "aws_lb_listener" "ollama" {
  load_balancer_arn = aws_lb.main.arn
  port              = 11434
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ollama.arn
  }
}

# Internal ALB for Ollama — routes traffic within VPC only, no public IP
resource "aws_lb" "ollama_internal" {
  name               = "${var.environment}-ollama-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups = [var.ollama_internal_alb_sg_id]
  subnets            = var.private_app_subnet_ids

  # LLM inference can take 60-120s — increase idle timeout to prevent disconnects
  idle_timeout = 300

  tags = { Name = "${var.project_name}-${var.environment}-ollama-internal-alb" }
}

# Listener on internal ALB — port 11434
resource "aws_lb_listener" "ollama_internal" {
  load_balancer_arn = aws_lb.ollama_internal.arn
  port              = 11434
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ollama_internal.arn
  }
}

# ── Launch Template ──────────────────────────────────────────
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-${var.environment}-lt-"
  image_id      = var.ami_id
  instance_type = var.asg_instance_type
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = [var.asg_sg_id]

  # IAM profile for SSM Session Manager access on LLM instances
  iam_instance_profile {
    name = var.asg_instance_profile_name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    systemctl start ollama
    systemctl enable ollama
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.project_name}-${var.environment}-llm-instance" }
  }
}

# ── Auto Scaling Group ───────────────────────────────────────
resource "aws_autoscaling_group" "main" {
  name                = "${var.project_name}-${var.environment}-asg"
  vpc_zone_identifier = var.private_app_subnet_ids
  min_size            = var.asg_min_size
  desired_capacity    = var.asg_desired_size
  max_size            = var.asg_max_size

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.ollama.arn,
    aws_lb_target_group.ollama_internal.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 600

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-asg-instance"
    propagate_at_launch = true
  }
}


# ── Scaling Policy ───────────────────────────────────────────
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.project_name}-${var.environment}-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
