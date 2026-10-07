resource "aws_s3_bucket" "workflow_demo" {
  # Changed from "session19-workflow-": every bucket in this homework account follows
  # abdur-24bcs10244-s<session>-<purpose>; AWS appends a unique suffix to the prefix.
  bucket_prefix = "abdur-24bcs10244-s19-workflow-"

  tags = {
    Name      = "Session 19 Workflow Demo"
    ManagedBy = "Terraform"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.workflow_demo.bucket
}
