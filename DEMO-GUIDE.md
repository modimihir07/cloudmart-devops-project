# CloudMart DevOps Project - Demo Guide

> **Made by Mihir Modi** - DevOps Capstone Project

This guide tells you exactly what to change to deploy CloudMart DevOps Project on your AWS free tier for a live demo, and how to destroy it afterwards.

---

## Prerequisites

- AWS Free Tier account (created within 12 months)
- AWS CLI configured
- Terraform, kubectl, Helm, Docker installed
- GitHub account

---

## Files You Must Change

Search the entire project for `YOUR_` and `REPLACE_` - these are the **only** values you need to modify.

### 1. Terraform State Backend (`terraform/live/dev/backend.tf`)

```hcl
bucket = "cloudmart-devops-project-tfstate"        # Must be globally unique → rename to "cloudmart-devops-project-tfstate-YOUR_INITIALS"
dynamodb_table = "cloudmart-devops-project-tfstate-lock"  # Same
```

### 2. Terraform Variables (`terraform/live/dev/terraform.tfvars`)

```hcl
region  = "us-east-1"    # Or your preferred region
environment = "dev"
```

### 3. Terraform Password (`terraform/modules/rds/main.tf`)

```hcl
password = "REPLACE_WITH_SECURE_PASSWORD"   # Change to a real password
```

### 4. Kubernetes Manifests (`k8s-manifests/base/*.yaml`)

Replace `YOUR_AWS_ACCOUNT_ID` with your 12-digit AWS account ID (find it: `aws sts get-caller-identity`):

```yaml
eks.amazonaws.com/role-arn: "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/cloudmart-dev-product-catalog-irsa"
image: YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/cloudmart-dev/product-catalog:latest
```

### 5. Ingress Hostname (`k8s-manifests/base/ingress.yaml`)

```yaml
host: cloudmart-dev.YOUR_IP.nip.io   # Replace YOUR_IP with your public IP or use *
# Better for demo: remove host entirely to match all traffic
```

### 6. ArgoCD Manifests (`argocd/project.yaml`, `argocd/dev-app.yaml`)

Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username.

### 7. GitHub Actions (`.github/workflows/ci.yml`)

Replace `YOUR_GITHUB_USERNAME` in `GITOPS_REPO`.

Set repository secrets:
- `AWS_ACCOUNT_ID`
- `AWS_ROLE_ARN`
- `GITOPS_TOKEN`

### 8. Simulation Scripts (`scripts/simulate-alarm.sh`)

Replace `YOUR_ACCOUNT_ID` with your AWS account ID.

### 9. Lambda (`scripts/lambda/pagerduty-forwarder.py`)

Replace `REPLACE_WITH_PAGERDUTY_KEY` when configuring PagerDuty integration.

### 10. KMS Key for Backups (`scripts/backup-rds.sh`)

Replace `YOUR_ACCOUNT_ID` in `S3_BUCKET`.

---

## Quick Demo Path (Skip What You Don't Need)

### Minimal Demo (1 hour, ~$0.50)
```bash
# 1. Create Terraform state bucket
aws s3 mb s3://cloudmart-devops-project-tfstate-MYNAME --region us-east-1

# 2. Edit backend.tf → use "cloudmart-devops-project-tfstate-MYNAME"
# 3. Edit all YOUR_AWS_ACCOUNT_ID → your actual account ID
# 4. Edit RDS passwords

# 5. Deploy infrastructure
cd terraform/live/dev
terraform init -reconfigure
terraform plan
terraform apply -auto-approve

# 6. Get kubeconfig
aws eks update-kubeconfig --name cloudmart-dev-eks --region us-east-1

# 7. Create secrets
kubectl create ns cloudmart-dev
kubectl create secret generic cloudmart-db-secrets -n cloudmart-dev \
  --from-literal=products-database-url="..."
# Use outputs from terraform output

# 8. Deploy apps
kubectl apply -k k8s-manifests/overlays/dev/

# 9. Install ALB controller + Ingress
# ... then access via ALB DNS

# 10. Demo the app - browse products, add to cart
# 11. Show Grafana dashboard
# 12. Show ArgoCD UI

# 13. Clean up
terraform destroy -auto-approve
```

---

## Free Tier Cost Optimization

| Resource | Free Tier | Recommended Setting |
|----------|-----------|-------------------|
| EKS cluster | No (control plane ~$0.10/hr) | Delete after demo |
| RDS (db.t4g.micro) | 750 hrs/mo free | Single AZ, no multi-AZ |
| ElastiCache (cache.t4g.micro) | 750 hrs/mo free | Single node |
| S3 | 5GB free | Minimal usage |
| ECR | 500MB free | Delete images after demo |
| ALB | No (~$0.025/hr) | Delete after demo |

**Estimated demo cost:** ~$1-3 for a full day of testing.

---

## Demo Script (5-Minute Walkthrough)

```
1. SHOW: Architecture diagram (docs/architecture.md)
   → "This is CloudMart DevOps Project, a microservices e-commerce platform on AWS EKS..."

2. SHOW: Terraform outputs
   → "Infrastructure provisioned with Terraform - VPC, EKS, RDS, Redis, all IaC."

3. SHOW: kubectl get pods -n cloudmart-dev
   → "4 services running: frontend, product-catalog, cart, order"

4. SHOW: Open the app URL
   → "Browse products, add to cart - it works."

5. SHOW: ArgoCD UI
   → "GitOps with auto-sync, self-heal, and prune."

6. SHOW: Grafana dashboard
   → "Real-time metrics: request rate, latency, error rate."

7. SHOW: GitHub Actions CI
   → "Lint → Test → CodeQL → Trivy → Build → Push → GitOps update"

8. CLOSE: "This project demonstrates: EKS, Terraform, GitHub Actions, ArgoCD,
   Prometheus/Grafana, EFK, Jaeger, DevSecOps, and automation."
```

---

## Cleanup Checklist

After demo, run these to avoid charges:

```bash
# 1. Delete all K8s resources
kubectl delete ns cloudmart-dev
kubectl delete ns monitoring
kubectl delete ns observability
kubectl delete ns argocd

# 2. Destroy Terraform infrastructure
cd terraform/live/dev
terraform destroy -auto-approve

# 3. Delete S3 buckets (after emptying)
aws s3 rb s3://cloudmart-dev-backups-ACCOUNT --force
aws s3 rb s3://cloudmart-devops-project-tfstate-MYNAME --force

# 4. Delete DynamoDB table
aws dynamodb delete-table --table-name cloudmart-devops-project-tfstate-lock

# 5. Verify nothing is running
aws ec2 describe-instances --query 'Reservations[].Instances[].State.Name'
```
