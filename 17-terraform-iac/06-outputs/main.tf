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
  region = "ap-south-1"

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

resource "aws_s3_bucket" "demo" {
  # Lecture prefix was "session18-output-"; changed to my naming convention
  # (globally unique, easy to find). AWS still appends a unique suffix.
  bucket_prefix = "abdur-24bcs10244-s18-06-output-"

  tags = {
    Name = "Session 18 Output Demo"
  }
}

output "bucket_id" {
  description = "The S3 bucket ID"
  value       = aws_s3_bucket.demo.id
}

output "bucket_arn" {
  description = "The S3 bucket ARN"
  value       = aws_s3_bucket.demo.arn
}

output "bucket_region" {
  description = "The AWS region"
  value       = "ap-south-1"
}

# Exercise: one more output
output "bucket_name" {
  value = aws_s3_bucket.demo.bucket
}
