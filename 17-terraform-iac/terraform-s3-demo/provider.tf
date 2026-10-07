# The homework asks for provider.tf. The lecture split this into terraform.tf
# (the terraform block) and providers.tf (the provider block); both are merged
# here unchanged, apart from the default_tags added below.

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
