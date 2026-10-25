locals {
  services = ["product-catalog", "cart-service", "order-service", "frontend"]
}

resource "aws_kms_key" "app" {
  description             = "CloudMart ${var.environment} application KMS key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "cloudmart-${var.environment}-app-kms"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "secrets_manager_read" {
  name        = "cloudmart-${var.environment}-secrets-manager-read"
  description = "Allow reading secrets from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = ["arn:aws:secretsmanager:${var.region}:*:secret:cloudmart-${var.environment}-*"]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [aws_kms_key.app.arn]
      },
    ]
  })
}

resource "aws_iam_policy" "s3_static_assets" {
  name        = "cloudmart-${var.environment}-s3-static-assets"
  description = "Allow access to CloudMart S3 static assets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["arn:aws:s3:::cloudmart-${var.environment}-static*/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = ["arn:aws:s3:::cloudmart-${var.environment}-static*"]
      },
    ]
  })
}

resource "aws_iam_role" "service_irsa" {
  for_each = toset(local.services)

  name               = "cloudmart-${var.environment}-${each.key}-irsa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["sts:AssumeRoleWithWebIdentity"]
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:cloudmart-${var.environment}:${each.key}"
          }
        }
      },
    ]
  })

  tags = {
    Name        = "cloudmart-${var.environment}-${each.key}-irsa"
    Service     = each.key
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "secrets_manager" {
  for_each   = toset(local.services)
  role       = aws_iam_role.service_irsa[each.key].name
  policy_arn = aws_iam_policy.secrets_manager_read.arn
}

resource "aws_iam_role_policy_attachment" "s3_static" {
  for_each   = toset(local.services)
  role       = aws_iam_role.service_irsa[each.key].name
  policy_arn = aws_iam_policy.s3_static_assets.arn
}
