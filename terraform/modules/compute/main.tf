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
    path                = "/api/v1/health"
    port                = "3000"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
  }

  tags = { Name = "${var.project_name}-${var.environment}-tg" }
}

# Separate Target Group for Ollama API (port 11434) — LLM instances,
# not the same as Flowise's target group (port 3000).
resource "aws_lb_target_group" "ollama" {
  name     = "${var.environment}-ollama-tg"
  port     = 11434
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    port                = "11434"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
  }

  tags = { Name = "${var.project_name}-${var.environment}-ollama-tg" }
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

# ── Launch Template ──────────────────────────────────────────
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-${var.environment}-lt-"
  image_id      = var.ami_id
  instance_type = var.asg_instance_type
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = [var.asg_sg_id]

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

  target_group_arns = [aws_lb_target_group.main.arn, aws_lb_target_group.ollama.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300

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
