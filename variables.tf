variable "aws_region" {
  description = "AWS region for the lab"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "poc-privatelink-overlap"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "instance_type" {
  description = "EC2 instance type for workload and partner test instance"
  type        = string
  default     = "t3.micro"
}

variable "workload_vpc_cidr" {
  description = "CIDR for the workload VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "partner_vpc_cidr" {
  description = "CIDR for the partner VPC. Keep equal to workload for overlap demonstration."
  type        = string
  default     = "10.10.0.0/16"
}
