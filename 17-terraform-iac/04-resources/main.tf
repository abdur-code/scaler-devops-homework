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
  # Lecture prefix was "session18-resource-"; changed to my naming convention
  # (globally unique, easy to find). AWS still appends a unique suffix.
  bucket_prefix = "abdur-24bcs10244-s18-04-resource-"

  tags = {
    Name        = "Session 18 Resource Demo"
    Environment = "dev"
    # Exercise: extra tags (Owner "student" in the notes -> my enrollment number)
    Project = "terraform-training"
    Owner   = "24BCS10244"
  }
}
