# terraform-example01

## Summary

This is an example of a basic Terraform plan for AWS infrastructure.

## AWS Components

 - EC2 instance
 - Security groups
 - Auto-scaling Groups and related lauch configuration
 - Elastic load-balancer

## Relationships

 - Security groups control traffic ingress & egress rules to EC2 instances and the ELB
 - The launch configuration defines what the auto-scaling group should launch
 - The elastic load-balancer defines a healthcheck to determine instance health