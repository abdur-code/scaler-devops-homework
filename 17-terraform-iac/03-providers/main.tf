terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Added: tag everything this homework creates in AWS so it can be found and
  # cleaned up later. Resource-level tags are merged on top of these.
  default_tags {
    tags = {
      Project = "scaler-devops-homework"
      Session = "18"
      Owner   = "24BCS10244"
    }
  }
}

variable "aws_region" {
  description = "AWS region for this lab"
  type        = string
  default     = "ap-south-1"
}

resource "aws_s3_bucket" "provider_demo" {
  # Lecture prefix was "session18-provider-"; changed to my naming convention
  # (globally unique, easy to find). AWS still appends a unique suffix.
  bucket_prefix = "abdur-24bcs10244-s18-03-provider-"

  tags = {
    Name = "Session 18 Provider Demo"
  }
}

output "bucket_id" {
  value = aws_s3_bucket.provider_demo.id
}
