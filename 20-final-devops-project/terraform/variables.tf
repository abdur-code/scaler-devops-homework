# Fix: one variable per line in the original was fine, but rewritten as normal blocks
# for consistency with the other files.
variable "aws_region" {
  default = "ap-south-1"
}

variable "cluster_name" {
  default = "taskboard-eks"
}

variable "environment" {
  default = "dev"
}
