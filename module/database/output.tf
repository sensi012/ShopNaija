output "db_endpoint" {
  value     = aws_db_instance.main.endpoint
  sensitive = true
}

output "db_instance_id" {
  value = aws_db_instance.main.id
}

output "secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}
