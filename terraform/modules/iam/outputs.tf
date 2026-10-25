output "service_irsa_roles" {
  description = "Map of service name to IRSA role ARN"
  value = {
    for k, v in aws_iam_role.service_irsa : k => v.arn
  }
}

output "kms_key_arn" {
  value = aws_kms_key.app.arn
}
