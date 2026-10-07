# Fix: the original file put this whole block on one line. HCL only allows one-line
# blocks with a single argument, so `terraform init` failed with
# "Invalid single-argument block definition". Same settings, written out normally.
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Added: tag everything this stack creates, so the post-destroy check can prove that
  # nothing was left behind in the account.
  default_tags {
    tags = {
      Project = "scaler-devops-homework"
      Session = "21"
      Owner   = "24BCS10244"
    }
  }
}
