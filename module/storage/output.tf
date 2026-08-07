output "bucket_name" {
  value = aws_s3_bucket.app_bucket.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.app_bucket.arn
}

output "bucket_id" {
  value = aws_s3_bucket.app_bucket.id
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.app_bucket.bucket_regional_domain_name
}
