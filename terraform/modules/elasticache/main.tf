resource "aws_elasticache_subnet_group" "this" {
  name       = "cloudmart-${var.environment}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "cloudmart-${var.environment}-redis-subnet-group"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "redis" {
  name        = "cloudmart-${var.environment}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    cidr_blocks     = ["10.0.0.0/16"]
    description     = "Allow Redis from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name        = "cloudmart-${var.environment}-redis-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "random_password" "redis_auth" {
  length      = 32
  special     = false
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  keepers = {
    environment = var.environment
  }
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name                    = "cloudmart-${var.environment}-redis-auth"
  description             = "CloudMart ${var.environment} Redis AUTH token"
  recovery_window_in_days = 7

  tags = {
    Name        = "cloudmart-${var.environment}-redis-auth"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = random_password.redis_auth.result
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id          = "cloudmart-${var.environment}-redis"
  description                   = "CloudMart ${var.environment} Redis cluster"
  engine                        = "redis"
  engine_version                = var.engine_version
  node_type                     = var.node_type
  num_cache_clusters            = 1
  parameter_group_name          = "default.redis7"
  port                          = 6379
  subnet_group_name             = aws_elasticache_subnet_group.this.name
  security_group_ids            = [aws_security_group.redis.id]
  automatic_failover_enabled    = false
  multi_az_enabled              = false
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = true
  auth_token                     = random_password.redis_auth.result
  auto_minor_version_upgrade    = true

  tags = {
    Name        = "cloudmart-${var.environment}-redis"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
