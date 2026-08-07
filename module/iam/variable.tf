variable "project_name" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "github_org" {
  type        = string
  description = "GitHub organisation or username"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}
