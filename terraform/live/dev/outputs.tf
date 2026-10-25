output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_products_endpoint" {
  value = module.rds_products.db_endpoint
}

output "rds_orders_endpoint" {
  value = module.rds_orders.db_endpoint
}

output "redis_endpoint" {
  value = module.elasticache.primary_endpoint
}

output "static_bucket" {
  value = aws_s3_bucket.static_assets.id
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.id
}

output "ecr_repositories" {
  value = {
    for k, v in aws_ecr_repository.services : k => v.repository_url
  }
}

output "service_irsa_roles" {
  value = module.iam.service_irsa_roles
}
