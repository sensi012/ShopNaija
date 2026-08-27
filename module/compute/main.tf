locals {
  # Automatically detect whether instance_type uses AWS Graviton (ARM64) or standard x86_64
  is_arm64 = can(regex("^[a-z]+[0-9]+g|^a1|^im4gn|^is4gen|^g5g", var.instance_type))
  ami_arch = local.is_arm64 ? "arm64" : "x86_64"
}

# Latest Amazon Linux 2023 AMI - dynamically matches the instance architecture (ARM64 vs x86_64)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-${local.ami_arch}"]
  }

  filter {
    name   = "architecture"
    values = [local.ami_arch]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.iam_instance_profile
  }

  vpc_security_group_ids = [var.ec2_sg_id]

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    project_name   = var.project_name
    db_secret_arn  = var.db_secret_arn
    db_endpoint    = var.db_endpoint
    s3_bucket_name = var.s3_bucket_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-app-instance-${var.environment}"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  # Deletion protection:
  # true  = Prevents accidental deletion of ALB via AWS API/Console/Terraform (causes `terraform destroy` to fail).
  # false = Allows Terraform to destroy the ALB during teardown.
  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
    matcher             = "200"
  }

  deregistration_delay = 30 # faster deploys - don't wait long for connection draining on a low-traffic health check target
}

# HTTP listener forwards traffic to target group (CloudFront connects over port 80)
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.app.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Self-signed certificate imported into ACM for immediate availability without DNS validation delay
resource "tls_private_key" "app" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "app" {
  private_key_pem = tls_private_key.app.private_key_pem

  subject {
    common_name  = "${var.project_name}.local"
    organization = "ShopNaija"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "app" {
  private_key      = tls_private_key.app.private_key_pem
  certificate_body = tls_self_signed_cert.app.cert_pem

  lifecycle {
    create_before_destroy = true
  }
}


# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = var.private_app_subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  health_check_type         = "ELB"
  health_check_grace_period = 90

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Spread instances evenly across AZs for fault tolerance
  availability_zone_distribution {
    capacity_distribution_strategy = "balanced-best-effort"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }
}

# Scale out on CPU - handles the "downtime during promotions" problem directly
resource "aws_autoscaling_policy" "scale_out_cpu" {
  name                   = "${var.project_name}-scale-out-cpu"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}
