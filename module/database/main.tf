
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-db"
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_security_group_id]
  publicly_accessible    = false

  multi_az = var.multi_az

  backup_retention_period = var.backup_retention_days
  backup_window           = "02:00-03:00" # low-traffic window, WAT-adjacent
  maintenance_window      = "sun:03:30-sun:04:30"

  # Deletion protection:
  # true  = AWS blocks deletion of the database instance (prevents accidental data loss in prod; causes `terraform destroy` to fail).
  # false = Allows AWS and Terraform to delete the RDS database instance.
  deletion_protection = false

  # Final snapshot:
  # false = Creates a final backup snapshot before deleting (requires a unique final_snapshot_identifier; fails if snapshot name already exists).
  # true  = Destroys database immediately without creating a final backup snapshot.
  skip_final_snapshot       = true
  final_snapshot_identifier = "${var.project_name}-db-final-snapshot"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name = "${var.project_name}-db"
  }
}

resource "random_password" "db_password" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}/rds/credentials"
  description = "RDS master credentials for ${var.project_name}"

  # recovery_window_in_days:
  # 7-30 = Retains deleted secret in recovery queue for N days (blocks recreating a secret with the same name).
  # 0    = Force-deletes immediately on destroy without recovery window so `terraform apply` can recreate it without errors.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = var.db_engine
    dbname   = var.db_name
  })
}


resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}
