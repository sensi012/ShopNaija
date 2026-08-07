# ------------------------------------------------------------------
# Networking
# ------------------------------------------------------------------
module "vpc" {
  source = "./module/vpc"

  project_name             = var.project_name
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  availability_zones       = var.availability_zones
  single_nat_gateway       = var.single_nat_gateway
}

# ------------------------------------------------------------------
# Security Groups
# ------------------------------------------------------------------
module "security" {
  source = "./module/security"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
}

# ------------------------------------------------------------------
# IAM Roles (least privilege)
# ------------------------------------------------------------------
module "iam" {
  source = "./module/iam"

  project_name  = var.project_name
  s3_bucket_arn = module.storage.bucket_arn
  db_secret_arn = module.database.secret_arn
  github_org    = var.github_org
  github_repo   = var.github_repo
}

# ------------------------------------------------------------------
# Storage (S3)
# ------------------------------------------------------------------
module "storage" {
  source = "./module/storage"

  project_name = var.project_name
}

# ------------------------------------------------------------------
# Database (RDS)
# ------------------------------------------------------------------
module "database" {
  source = "./module/database"

  project_name          = var.project_name
  db_subnet_ids         = module.vpc.private_db_subnet_ids
  db_security_group_id  = module.security.rds_sg_id
  db_engine             = var.db_engine
  db_engine_version     = var.db_engine_version
  db_instance_class     = var.db_instance_class
  db_name               = var.db_name
  db_username           = var.db_username
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
}

# ------------------------------------------------------------------
# Compute (ALB + ASG + Launch Template)
# ------------------------------------------------------------------
module "compute" {
  source = "./module/compute"

  project_name           = var.project_name
  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  private_app_subnet_ids = module.vpc.private_app_subnet_ids
  alb_sg_id              = module.security.alb_sg_id
  ec2_sg_id              = module.security.ec2_sg_id
  instance_type          = var.instance_type
  iam_instance_profile   = module.iam.ec2_instance_profile_name
  asg_min_size           = var.asg_min_size
  asg_max_size           = var.asg_max_size
  asg_desired_capacity   = var.asg_desired_capacity
  db_secret_arn          = module.database.secret_arn
  db_endpoint            = module.database.db_endpoint
  s3_bucket_name         = module.storage.bucket_name
}

# ------------------------------------------------------------------
# Lambda (image processing on S3 upload)
# ------------------------------------------------------------------
module "lambda" {
  source = "./module/lambda"

  project_name    = var.project_name
  s3_bucket_name  = module.storage.bucket_name
  s3_bucket_arn   = module.storage.bucket_arn
  lambda_role_arn = module.iam.lambda_role_arn
  sns_topic_arn   = module.monitoring.sns_topic_arn
}

# ------------------------------------------------------------------
# API Gateway (exposes Lambda as REST API)
# ------------------------------------------------------------------
module "api_gateway" {
  source = "./module/api_gateway"

  project_name         = var.project_name
  lambda_function_arn  = module.lambda.function_arn
  lambda_function_name = module.lambda.function_name
}

# ------------------------------------------------------------------
# CDN (CloudFront - ALB origin for dynamic, S3 origin for static assets)
# ------------------------------------------------------------------
module "cdn" {
  source = "./module/cdn"

  project_name                   = var.project_name
  alb_dns_name                   = module.compute.alb_dns_name
  s3_bucket_regional_domain_name = module.storage.bucket_regional_domain_name
  s3_bucket_id                   = module.storage.bucket_id
  acm_certificate_arn            = var.domain_name != "" ? aws_acm_certificate.cdn[0].arn : ""
  domain_aliases                 = var.domain_name != "" ? [var.domain_name] : []
}

resource "aws_acm_certificate" "cdn" {
  count             = var.domain_name != "" ? 1 : 0
  provider          = aws.us_east_1 # CloudFront requires ACM certs to be in us-east-1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_s3_bucket_policy" "cloudfront_oac" {
  bucket = module.storage.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.storage.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cdn.distribution_arn
          }
        }
      }
    ]
  })
}
# ------------------------------------------------------------------
# Monitoring (CloudWatch alarms + SNS)
# ------------------------------------------------------------------
module "monitoring" {
  source = "./module/monitoring"

  project_name   = var.project_name
  alert_email    = var.alert_email
  asg_name       = module.compute.asg_name
  db_instance_id = module.database.db_instance_id
}
