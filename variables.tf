variable "region" {
  description = "AWS region for the PoC."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for workload and partner test hosts."
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Prefix used in resource names."
  type        = string
  default     = "privatelink-poc"
}

variable "workload_vpc_cidr" {
  description = "CIDR for the workload VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "partner_vpc_cidr" {
  description = "CIDR for the partner VPC. Must intentionally overlap to prove the concept."
  type        = string
  default     = "10.10.0.0/16"
}

variable "allowed_management_cidrs" {
  description = "Optional CIDRs for additional management access. Not used by default because Session Manager is the access path."
  type        = list(string)
  default     = []
}
