# Generated by Terragrunt. Sig: nIlQXj57tbuaRZEa
terraform {
  backend "s3" {
    bucket         = "asmigar-prod-create-k8s-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    profile        = "asmigar"
    encrypt        = true
    dynamodb_table = "create-k8s-state-locks"
  }
}
