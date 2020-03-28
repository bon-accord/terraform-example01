# START: SPECIFY CLOUD PROVIDER

provider "aws" {
    region = "eu-west-2"
}

# DEFINE EC2 INSTANCE

resource "aws_instance" "example-resource" {
    # ami             =  "ami-0c55b159cbfafe1f0"    
    ami             =  "ami-0c216d3ab383cc403"    
    instance_type   = "t2.micro"
    vpc_security_group_ids = [aws_security_group.secgrp-instance.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello "${var.hello_target}"'s World! from Host $(hostname) on Date $(date "+%Y-%m-%d") @ $(date "+%H:%M:%S") hrs" > index.html
                nohup busybox httpd -f -p "${var.server_port}" &
                EOF

    tags = {
        Name = "terraform-example"
    }
}

# DEFINE SECURITY GROUP

resource "aws_security_group" "secgrp-instance" {
    name = "terraform-example-instance"

    ingress {
        from_port   = var.server_port
        to_port     = var.server_port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "elb" {
    name = "terraform-example-elb"

    # Allow all outbounfd
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # Allow inbound HTTP from anywhere
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


# DEFINE VARIABLES

variable "server_port" {
    description = "Server port listening for HTTP requests"
    type        = number 
    default     = 8080
}

variable "hello_target" {
    description = "The argument for the hello world command"
    type        = string
    default     = "Lewis"
}

output "public_ip" {
    value       = aws_instance.example-resource.public_ip
    description = "The public IP of the web server"
}

# DEFINE ASGs & LAUNCH CONFIGURATIONS

resource "aws_launch_configuration" "example" {
    name_prefix     = "lewis-launch-config"
    image_id        = "ami-0c216d3ab383cc403"    
    instance_type   = "t2.micro"
    security_groups = [aws_security_group.secgrp-instance.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello "${var.hello_target}"'s World! from Host $(hostname) on Date $(date "+%Y-%m-%d") @ $(date "+%H:%M:%S") hrs" > index.html
                nohup busybox httpd -f -p "${var.server_port}" &
                EOF

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration  = aws_launch_configuration.example.id
  availability_zones    = data.aws_availability_zones.all.names

  min_size = 2
  max_size = 10

  load_balancers    = [aws_elb.example.name]
  health_check_type = "ELB"

  tag {
      key                   = "Name"
      value                 = "terraform-asg-example"
      propagate_at_launch   = true
  }
}

# DEFINE DATA SOURCES

data "aws_availability_zones" "all" {}

# DEFINE LOAD-BALANCER (CLB TYPE)

resource "aws_elb" "example" {
  name                  = "terraform-asg-example"
  security_groups       = [aws_security_group.elb.id]
  availability_zones    = data.aws_availability_zones.all.names

  health_check {
      target                = "HTTP:${var.server_port}/"
      interval              = 30
      timeout               = 3
      healthy_threshold     = 2
      unhealthy_threshold   = 2
  }

  listener {
      lb_port           = 80
      lb_protocol       = "http"
      instance_port     = var.server_port
      instance_protocol = "http"
  }
}

output "clb_dns_name" {
  value         = aws_elb.example.dns_name
  description   = "The domain of the load balancer"
}


