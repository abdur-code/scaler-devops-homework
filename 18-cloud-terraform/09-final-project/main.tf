# Session 19 final project: the 08 mini-project network, plus one EC2 web server and one
# S3 bucket. Network resources are copied from 08; CIDRs and names now come from variables.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "${var.project_name}-vpc"
    Session   = "19"
    ManagedBy = "Terraform"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name      = "${var.project_name}-public-subnet"
    Session   = "19"
    ManagedBy = "Terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-igw"
    Session   = "19"
    ManagedBy = "Terraform"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name      = "${var.project_name}-public-rt"
    Session   = "19"
    ManagedBy = "Terraform"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Changed from 08: HTTP is allowed from my IP only, HTTPS is dropped (nothing listens on
# 443), and there is no SSH rule at all.
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "HTTP from my IP only, no SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from my IP only"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    description = "Allow outbound IPv4 (dnf needs it at boot)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.project_name}-web-sg"
    Session   = "19"
    ManagedBy = "Terraform"
  }
}

# Latest Amazon Linux 2023 (x86_64) AMI ID, read from the public SSM parameter that AWS
# keeps up to date. No hardcoded AMI ID: those differ per region and change every release.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023.insecure_value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  # No key_name on purpose: there is no key pair and no SSH rule, nobody logs in.

  user_data = <<-EOT
    #!/bin/bash
    dnf install -y httpd
    echo "<h1>Session 19 final project</h1><p>Abdur Rahman Ibne Munir (24BCS10244)</p><p>Served by $(hostname -f), created with Terraform</p>" > /var/www/html/index.html
    systemctl enable --now httpd
  EOT

  # Explicit dependency. The instance only references the subnet and the security group,
  # so Terraform would happily boot it before the route to the internet gateway exists.
  # user_data runs `dnf install` on first boot and needs that route, so wait for it.
  depends_on = [aws_route_table_association.public]

  # default_tags do not reach the root EBS volume, so tag it here.
  volume_tags = {
    Name    = "${var.project_name}-web-root"
    Project = "scaler-devops-homework"
    Session = "19"
    Owner   = "24BCS10244"
  }

  tags = {
    Name      = "${var.project_name}-web"
    Session   = "19"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket = var.bucket_name

  # Lets `terraform destroy` delete the bucket even if objects are still in it.
  force_destroy = true

  tags = {
    Name      = "${var.project_name}-bucket"
    Session   = "19"
    ManagedBy = "Terraform"
  }
}
