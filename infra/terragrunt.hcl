generate "backend" {
  path      = "remote_backend.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  backend "s3" {
    bucket         = "asmigar-${path_relative_to_include()}-create-k8s-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    profile        = "asmigar"
    encrypt        = true
    dynamodb_table = "create-k8s-state-locks"
  }
}
EOF
}
