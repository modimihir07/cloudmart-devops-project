resource "aws_db_subnet_group" "this" {
  name       = "cloudmart-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "cloudmart-${var.environment}-db-subnet-group"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "rds" {
  name        = "cloudmart-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = ["10.0.0.0/16"]
    description     = "Allow PostgreSQL from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name        = "cloudmart-${var.environment}-rds-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption - ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "cloudmart-${var.environment}-rds-kms"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "random_password" "this" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  keepers = {
    environment = var.environment
    db_name     = var.db_name
  }
}

resource "aws_secretsmanager_secret" "this" {
  name                    = "cloudmart-${var.environment}-${var.db_name}-password"
  description             = "CloudMart ${var.environment} ${var.db_name} master password"
  kms_key_id              = aws_kms_key.rds.arn
  recovery_window_in_days = 7

  tags = {
    Name        = "cloudmart-${var.environment}-${var.db_name}-password"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = random_password.this.result
}

resource "aws_db_instance" "this" {
  identifier        = "cloudmart-${var.environment}-${var.db_name}"
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.allocated_storage
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.this.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot  = var.environment == "prod" ? false : true
  deletion_protection  = var.environment == "prod" ? true : false
  copy_tags_to_snapshot = true

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name        = "cloudmart-${var.environment}-${var.db_name}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
