# Fix: both module blocks were written on a single line each, which is not valid HCL
# ("Invalid single-argument block definition"), so `terraform init` failed. The
# arguments below are the lecture's own, written out one per line, except where noted.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name            = "taskboard-vpc"
  cidr            = "10.20.0.0/16"
  azs             = ["ap-south-1a", "ap-south-1b"]
  private_subnets = ["10.20.1.0/24", "10.20.2.0/24"]
  public_subnets  = ["10.20.101.0/24", "10.20.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.1"

  cluster_name = var.cluster_name

  # Changed from "1.31": 1.31 is now in EKS *extended* support, which bills the control
  # plane at a much higher hourly rate. 1.34 is the oldest version still in standard
  # support (checked with `aws eks describe-cluster-versions`).
  cluster_version = "1.34"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  # Added for cleanup safety: by default this module creates a customer-managed KMS key
  # for secrets encryption. `terraform destroy` can only *schedule* a KMS key for deletion,
  # so it would outlive the lab. EKS still encrypts secrets with an AWS-owned key.
  create_kms_key            = false
  cluster_encryption_config = {}

  # Added for cleanup safety: control-plane logging is on by default and writes to a
  # CloudWatch log group. EKS can keep flushing logs while the cluster is being deleted
  # and re-create that log group after Terraform has removed it, leaving a billable
  # leftover. Not needed for this lab.
  cluster_enabled_log_types   = []
  create_cloudwatch_log_group = false

  eks_managed_node_groups = {
    main = {
      # Fix: was "t3.medium". My AWS account is on the Free plan, which only allows
      # Free-Tier-eligible instance types, so the node group's Auto Scaling group could
      # never launch a node ("The specified instance type is not eligible for Free Tier")
      # and the apply hung on the node group for 30+ minutes. t3.small is the cheapest
      # eligible type that can run the EKS system pods (2 vCPU, 2 GiB).
      instance_types = ["t3.small"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2

      # Added: this module version defaults to Amazon Linux 2 node images, which EKS no
      # longer publishes for Kubernetes 1.33+. AL2023 is the supported replacement.
      ami_type = "AL2023_x86_64_STANDARD"
    }
  }
}
