variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_app_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "ec2_sg_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "iam_instance_profile" {
  type = string
}

variable "asg_min_size" {
  type = number
}

variable "asg_max_size" {
  type = number
}

variable "asg_desired_capacity" {
  type = number
}

variable "db_secret_arn" {
  type = string
}

variable "db_endpoint" {
  type      = string
  sensitive = true
}

variable "s3_bucket_name" {
  type = string
}
