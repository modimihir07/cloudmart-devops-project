# CloudMart DevOps Project - Full Deployment Instructions

> **Made by Mihir Modi** - DevOps Capstone Project

Complete step-by-step guide to deploy CloudMart DevOps Project on AWS.

---

## Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| AWS CLI | ≥ 2.x | `aws --version` |
| Terraform | ≥ 1.7 | `terraform --version` |
| kubectl | ≥ 1.28 | `kubectl version --client` |
| Helm | ≥ 3.14 | `helm version` |
| Docker | ≥ 24 | `docker --version` |
| Python | ≥ 3.12 | `python3 --version` |
| AWS account | Active | `aws sts get-caller-identity` |

---

## Step 1: Clone Repositories

```bash
# Application repo
git clone https://github.com/YOUR_GITHUB_USERNAME/cloudmart-devops-project.git
cd cloudmart-devops-project

# GitOps repo (separate repo for ArgoCD)
git clone https://github.com/YOUR_GITHUB_USERNAME/cloudmart-devops-project-gitops.git
```

---

## Step 2: Configure AWS Credentials

```bash
# Option A: Use IAM user with programmatic access
aws configure
# AWS Access Key ID: [YOUR_KEY]
# AWS Secret Access Key: [YOUR_SECRET]
# Default region: us-east-1

# Option B: Use IAM Role (recommended for CI/CD)
aws sts assume-role --role-arn "arn:aws:iam::YOUR_ACCOUNT_ID:role/CloudMartAdmin" --role-session-name CloudMartDeploy
```

---

## Step 3: Bootstrap Terraform Backend

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://cloudmart-devops-project-tfstate --region us-east-1
aws s3api put-bucket-versioning \
    --bucket cloudmart-devops-project-tfstate \
    --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name cloudmart-devops-project-tfstate-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

---

## Step 4: Deploy Infrastructure with Terraform

```bash
cd terraform/live/dev

# Review and update variables
vim terraform.tfvars  # Set your region, CIDRs, etc.

# Initialize
terraform init

# Review the plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan
```

**Resources created:**
- VPC with public/private subnets across 2 AZs
- EKS cluster (K8s 1.31) with managed node group (t3.medium × 2)
- RDS PostgreSQL × 2 (products + orders, db.t4g.micro)
- ElastiCache Redis (cache.t4g.micro)
- IAM roles with IRSA for each service
- ECR repositories (4)
- S3 buckets (static assets + backups)

---

## Step 5: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --name cloudmart-dev-eks --region us-east-1

# Verify
kubectl get nodes
kubectl get ns
```

---

## Step 6: Create Kubernetes Secrets

```bash
# Create namespace first
kubectl create namespace cloudmart-dev

# Create secrets for database access
# (Use AWS Secrets Manager or create manually for dev)

kubectl create secret generic cloudmart-db-secrets \
    -n cloudmart-dev \
    --from-literal=products-database-url="postgresql://cloudmart:PASSWORD@products.XXXXXX.us-east-1.rds.amazonaws.com:5432/products" \
    --from-literal=orders-database-url="postgresql://cloudmart:PASSWORD@orders.XXXXXX.us-east-1.rds.amazonaws.com:5432/orders" \
    --from-literal=redis-url="redis://PASSWORD@cloudmart-dev-redis.XXXXXX.ng.0001.use1.cache.amazonaws.com:6379"
```

---

## Step 7: Install ArgoCD

```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Apply CloudMart ArgoCD applications
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/dev-app.yaml
```

---

## Step 8: Deploy Microservices with ArgoCD

```bash
# The ArgoCD Application will auto-sync.
# Monitor the sync status:
argocd app get cloudmart-dev

# Or manually trigger sync:
argocd app sync cloudmart-dev

# Verify all pods are running:
kubectl get pods -n cloudmart-dev -w
```

---

## Step 9: Install AWS Load Balancer Controller

```bash
# Install ALB Ingress Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=cloudmart-dev-eks \
    --set serviceAccount.create=true \
    --set region=us-east-1 \
    --set vpcId=$(terraform output -raw vpc_id)

# Get the Ingress hostname
kubectl get ingress -n cloudmart-dev
```

---

## Step 10: Install Observability Stack

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add elastic https://helm.elastic.co
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Install Prometheus + Grafana
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    -n monitoring --create-namespace

# Apply ServiceMonitors and AlertingRules
kubectl apply -f monitoring/prometheus/

# Import Grafana dashboard
# Login to Grafana: kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# Default credentials: admin / prom-operator
# Import monitoring/grafana/dashboards/cloudmart-dashboard.json

# Install Jaeger Operator
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/latest/download/jaeger-operator.yaml -n observability
kubectl apply -f monitoring/tracing/jaeger.yaml

# Install OpenTelemetry Operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
kubectl apply -f monitoring/tracing/otel-collector.yaml

# Install EFK Stack
# (Requires ECK Operator for Elasticsearch on K8s)
kubectl create -f https://download.elastic.co/downloads/eck/2.14.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.14.0/operator.yaml
kubectl apply -f monitoring/logging/elasticsearch.yaml
kubectl apply -f monitoring/logging/fluentbit-config.yaml
```

---

## Step 11: Test the Application

```bash
# Get the ALB URL
INGRESS_HOST=$(kubectl get ingress cloudmart-ingress -n cloudmart-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://${INGRESS_HOST}"

# Test endpoints
curl -s "http://${INGRESS_HOST}/api/products" | head -50
curl -s -X POST "http://${INGRESS_HOST}/api/cart/items" \
    -H "Content-Type: application/json" \
    -d '{"product_id":1,"name":"Test","price":10.00,"quantity":1}'
```

---

## Step 12: Set Up CI/CD

Push the code to GitHub:
```bash
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/cloudmart-devops-project.git
git push -u origin main
```

GitHub repository secrets required:
| Secret | Value |
|--------|-------|
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |
| `AWS_ROLE_ARN` | IAM role ARN for GitHub Actions OIDC |
| `GITOPS_TOKEN` | GitHub PAT with repo access |

---

## Cleanup

```bash
# Destroy all resources
cd terraform/live/dev
terraform destroy

# Delete S3 buckets (must be empty first)
aws s3 rm s3://cloudmart-dev-backups-ACCOUNT --recursive
aws s3 rb s3://cloudmart-dev-backups-ACCOUNT
aws s3 rb s3://cloudmart-devops-project-tfstate --force
aws dynamodb delete-table --table-name cloudmart-devops-project-tfstate-lock
```
