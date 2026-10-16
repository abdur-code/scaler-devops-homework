# The original was valid. I only rewrote the variables as normal blocks so they match the
# other files.
variable "aws_region" {
  default = "ap-south-1"
}

variable "cluster_name" {
  default = "taskboard-eks"
}

variable "environment" {
  default = "dev"
}
