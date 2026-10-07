# Added: values for this run. No secrets here (credentials come from the AWS CLI
# profile, never from Terraform files).
aws_region = "ap-south-1"

# The default in variables.tf ("yatri1107") already belongs to another AWS
# account (head-bucket returns 403), so I use my own globally unique name.
bucket_name = "abdur-24bcs10244-s18-s3-demo"
