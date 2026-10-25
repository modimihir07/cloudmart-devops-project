output "db_instance_id" {
  value = aws_db_instance.this.id
}

output "db_endpoint" {
  value = aws_db_instance.this.endpoint
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "db_username" {
  value = aws_db_instance.this.username
}

output "kms_key_arn" {
  value = aws_kms_key.rds.arn
}

output "security_group_id" {
  value = aws_security_group.rds.id
}

output "db_password_secret_arn" {
  value = aws_secretsmanager_secret.this.arn
}
