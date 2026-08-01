terraform {
  backend "s3" {
    bucket         = "shopnaija-bucket-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    use_lockfile   = true
  }
}
