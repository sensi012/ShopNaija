variable "project_name" {
  type = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB - dynamic content origin"
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket - static content origin"
  type        = string
}

variable "s3_bucket_id" {
  type = string
}

variable "acm_certificate_arn" {
  description = "ACM cert ARN - MUST be in us-east-1, CloudFront requirement regardless of app region"
  type        = string
}

variable "domain_aliases" {
  description = "Custom domain names for the distribution"
  type        = list(string)
  default     = []
}
