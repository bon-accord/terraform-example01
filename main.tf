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
                echo "Hello "${var.hello_target}"'s World! on $(date "+%Y-%m-%d") @ $(date "+%H:%M:%S")" > index.html
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
    image_id        = "ami-0c216d3ab383cc403"    
    instance_type   = "t2.micro"
    security_groups = [aws_security_group.secgrp-instance.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello "${var.hello_target}"'s World! on $(date "+%Y-%m-%d") @ $(date "+%H:%M:%S")" > index.html
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

  tag {
      key                   = "Name"
      value                 = "terraform-asg-example"
      propagate_at_launch   = true
  }
}

# DEFINE DATA SOURCES

data "aws_availability_zones" "all" {}

# DEFINE LOAD-BALANCER (CLB TYPE)


