variable "aws_region" {
  description = "AWS region for the Session 19 final project."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix used in the Name tag of every resource."
  type        = string
  default     = "session19-final"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block of the public subnet (must fit inside vpc_cidr)."
  type        = string
  default     = "10.20.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for the web server."
  type        = string
  default     = "t3.micro"

  # Cost guard: refuse anything bigger than a free-tier-sized x86 instance.
  validation {
    condition     = contains(["t3.micro", "t3.nano"], var.instance_type)
    error_message = "Use t3.micro or t3.nano for this homework (the AMI below is x86_64)."
  }
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name (abdur-24bcs10244-s19-<purpose>)."
  type        = string
}

variable "my_ip_cidr" {
  description = "My public IPv4 as a /32. The only source allowed to reach port 80."
  type        = string
  # Marked sensitive so my home IP is masked in plan/apply output and screenshots.
  sensitive = true

  validation {
    condition     = endswith(var.my_ip_cidr, "/32")
    error_message = "my_ip_cidr must be a single address, e.g. 203.0.113.10/32."
  }
}
