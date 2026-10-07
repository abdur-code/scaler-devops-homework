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

  # Added: tag every resource this provider creates, so I can find (and prove I removed)
  # everything that belongs to this homework in the shared AWS account.
  default_tags {
    tags = {
      Project = "scaler-devops-homework"
      Session = "19"
      Owner   = "24BCS10244"
    }
  }
}
