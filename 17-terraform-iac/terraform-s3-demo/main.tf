resource "aws_s3_bucket" "devops553" {
  bucket        = var.bucket_name
  force_destroy = true
  tags = {
    Name        = var.bucket_name
    Environment = "dev"
    ManagedBy   = "Terraform"
    # Lecture had Project = "Session18" here. A resource tag overrides the
    # provider default_tags, so it is removed; Project now comes from provider.tf.
  }
}
