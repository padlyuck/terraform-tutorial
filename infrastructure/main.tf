terraform {
  required_version = ">=1.6, <1.7"
}
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}
variable "aws_access_key_id" { type = string }
variable "aws_secret_access_key" { type = string }
variable "aws_region" { type = string }
variable "server_http_port" { type = number }
resource "aws_security_group" "instance" {
  name = "terraform-example-instance"
}
resource "aws_security_group_rule" "inbound_http" {
  from_port         = var.server_http_port
  protocol          = "tcp"
  security_group_id = aws_security_group.instance.id
  to_port           = var.server_http_port
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}
data "aws_vpc" "default" {
  default = true
}
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
resource "aws_launch_configuration" "example" {
  image_id        = "ami-06dd92ecc74fdfb36"
  instance_type   = "t2.micro"
  security_groups = [
    aws_security_group.instance.id
  ]
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup bash -c "python3 -m http.server ${var.server_http_port}" &
              EOF
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnets.default.ids
  max_size             = 10
  min_size             = 0
  desired_capacity = 0
  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "terraform-asg-example"
  }
  target_group_arns = [aws_alb_target_group.asg.arn]
  health_check_type = "ELB"
}
resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  subnets            = data.aws_subnets.default.ids
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found"
      status_code  = "404"
    }
  }
}
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.asg.arn
  }
}
resource "aws_alb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_http_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
resource "aws_security_group" "alb" {
  name = "terraform-example-alb"
}
resource "aws_security_group_rule" "alb_inbound_http" {
  from_port         = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  to_port           = 80
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "alb_outbound_any" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.alb.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}
output "alb_dns_name" {
  value = aws_lb.example.dns_name
}
