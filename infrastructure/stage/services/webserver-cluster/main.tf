terraform {
  required_version = ">=1.6, <1.7"
}
data "template_file" "user_data" {
  template = file("${path.module}/resources/user-data.sh")
  vars = {
    server_http_port = var.server_http_port
  }
}
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
resource "aws_launch_configuration" "example" {
  image_id        = "ami-06dd92ecc74fdfb36"
  instance_type   = "t2.micro"
  security_groups = [
    aws_security_group.instance.id
  ]
  user_data = data.template_file.user_data.rendered
  lifecycle {
    create_before_destroy = true
  }
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
resource "aws_autoscaling_group" "_" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnets.default.ids
  max_size             = 10
  min_size             = 1
  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "terraform-asg-example"
  }
  target_group_arns = [aws_alb_target_group.asg.arn]
  health_check_type = "ELB"
}
resource "aws_lb" "main_lb" {
  name               = "terraform-asg-example"
  subnets            = data.aws_subnets.default.ids
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
}
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.main_lb.arn
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
resource "aws_lb_listener_rule" "_" {
  listener_arn = aws_lb_listener.http_listener.arn
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
