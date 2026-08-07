variable "project_name" {
  description = "Project name used for tagging and naming resources"
  type        = string
  default     = "shopnaija"
}

variable "environment" {
  description = "Deployment environment (e.g. production, staging)"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1" # Ireland - closer to Nigeria than us-east-1; consider af-south-1 (Cape Town) if services you need are available there
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private database subnets"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ to save cost (early-stage tradeoff - reduces AZ fault tolerance for outbound traffic)"
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type for the application tier"
  type        = string
  default     = "t3.medium"
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 6
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}


variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "15.13"
}

variable "db_name" {
  type    = string
  default = "shopnaija"
}

variable "db_username" {
  description = "Master username for RDS - password is generated and stored in Secrets Manager, never in tfvars"
  type        = string
  default     = "shopnaija_admin"
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "db_backup_retention_days" {
  type    = number
  default = 7
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications (SNS)"
  type        = string
  default     = "devops@shopnaija.com"
}

variable "domain_name" {
  description = "Domain name for the application (used for ACM cert / CloudFront), leave empty to skip"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "ShopNaija"
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}

# GitHub OIDC - used to scope which GitHub repo can assume the deployment role
variable "github_org" {
  description = "GitHub organisation or username (e.g. sensi012)"
  type        = string
  default     = "sensi012"
}

variable "github_repo" {
  description = "GitHub repository name (e.g. ShopNaija)"
  type        = string
  default     = "*"
}
