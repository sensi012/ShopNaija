output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "Public DNS name of the load balancer - point your domain's CNAME/ALIAS here"
  value       = module.compute.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint (private - only reachable from within the VPC)"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  value = module.storage.bucket_name
}

output "api_gateway_invoke_url" {
  value = module.api_gateway.invoke_url
}

output "asg_name" {
  value = module.compute.asg_name
}

output "sns_topic_arn" {
  description = "Subscribe additional alert endpoints here"
  value       = module.monitoring.sns_topic_arn
}
