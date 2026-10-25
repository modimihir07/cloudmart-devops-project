data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

module "vpc" {
  source = "../../modules/vpc"

  environment           = var.environment
  region                = var.region
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
}

module "rds_products" {
  source = "../../modules/rds"

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  db_name            = "products"
  db_username        = "cloudmart"
  db_instance_class  = "db.t4g.micro"
}

module "rds_orders" {
  source = "../../modules/rds"

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  db_name            = "orders"
  db_username        = "cloudmart"
  db_instance_class  = "db.t4g.micro"
}

module "elasticache" {
  source = "../../modules/elasticache"

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  node_type          = "cache.t4g.micro"
}

module "eks" {
  source = "../../modules/eks"

  environment          = var.environment
  region               = var.region
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  cluster_version      = "1.31"
  node_instance_types  = ["t3.medium"]
  node_desired_size    = 2
  node_min_size        = 1
  node_max_size        = 3
  node_disk_size       = 20
  public_access_cidrs  = var.eks_public_access_cidrs
}

module "iam" {
  source = "../../modules/iam"

  environment       = var.environment
  region            = var.region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  eks_cluster_name  = module.eks.cluster_name
}

resource "aws_s3_bucket" "static_assets" {
  bucket = "cloudmart-${var.environment}-static-${local.account_id}"

  tags = {
    Name        = "cloudmart-${var.environment}-static"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket                  = aws_s3_bucket.static_assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "backups" {
  bucket = "cloudmart-${var.environment}-backups-${local.account_id}"

  tags = {
    Name        = "cloudmart-${var.environment}-backups"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ecr_repository" "services" {
  for_each = toset(["frontend", "product-catalog", "cart-service", "order-service"])

  name                 = "cloudmart-${var.environment}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "cloudmart-${var.environment}/${each.key}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
