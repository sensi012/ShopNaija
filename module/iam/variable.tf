variable "project_name" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

# GitHub OIDC - restrict which repo can assume the deployment role
variable "github_org" {
  type        = string
  description = "GitHub organisation or username (e.g. sensi012)"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (e.g. ShopNaija)"
}
