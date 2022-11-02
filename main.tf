# Building A Web Server

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.37.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_launch_configuration" "example" {
  ami                    = "ami-0fb653ca2d3203ac1"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World!" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "server_port" {
  description = "The port the server uses for HTTP."
  type = number
  default = 8080
}

output "public_ip" {
  value = aws_instance.example.public_ip
  description = "Public ip of the web server"
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example
  vpc_zone_identifier = data.aws_subnets.default.ids 

  min_size = 2
  max_size = 10

  tag {
    key         = "Name"
    value =     = "terraform-asg-example"
    propagate_at_launch = true
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
    values = ["data.aws_vpc.default.id"]
  }
}

resource "aws_lb" "example" {
  name = "terraform-asg-example"
  load_balancer_type = "application"
  subnets = data.aws_subnets.default.ids  
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = "aws_lb.example.arn"
  port = 80
  protocol = "HTTP"

  # By default it returns a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code = 404
    }
  }
  
}