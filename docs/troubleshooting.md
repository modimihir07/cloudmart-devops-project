# CloudMart DevOps Project - Troubleshooting Guide

> **Made by Mihir Modi** - DevOps Capstone Project

Common issues and their solutions.

---

## Terraform

### `Error: creating EKS Cluster: AccessDeniedException`
**Cause:** IAM user/role doesn't have sufficient permissions.
**Fix:** Attach `AmazonEKSClusterPolicy` and `AmazonEKSVPCResourceController` to your IAM role.

### `Error: creating EKS Node Group: InvalidParameterException`
**Cause:** Instance type not available in the selected AZ.
**Fix:** Check available instance types: `aws ec2 describe-instance-type-offerings --region us-east-1`

### `Error: creating RDS instance: StorageTypeNotSupported`
**Cause:** `gp3` not available in older regions.
**Fix:** Change to `gp2` in `terraform/modules/rds/main.tf`.

### State lock errors
```bash
# Force unlock (only if no other process is running)
terraform force-unlock LOCK_ID
```

---

## Kubernetes

### Pods stuck in `Pending` state
```bash
kubectl describe pod POD_NAME -n cloudmart-dev
# Check for:
# - Insufficient CPU/memory (resource limits too high for node size)
# - PVC not bound (if using persistent volumes)
# - Node selector/label mismatch
```

### Pods stuck in `CrashLoopBackOff`
```bash
kubectl logs POD_NAME -n cloudmart-dev
kubectl logs POD_NAME -n cloudmart-dev --previous  # Previous crashed instance

# Common causes:
# - Database connection failure (wrong host/credentials)
# - Missing secrets
# - Environment variables not set
```

### ImagePullBackOff
```bash
kubectl describe pod POD_NAME -n cloudmart-dev
# Common causes:
# - ECR repository doesn't exist
# - IAM role for node group doesn't have ECR permissions
# - Wrong image tag
```

### ALB Ingress not provisioning
```bash
# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify service account exists
kubectl get sa -n kube-system aws-load-balancer-controller

# Check ingress events
kubectl describe ingress cloudmart-ingress -n cloudmart-dev
```

---

## ArgoCD

### Application stuck in `OutOfSync`
```bash
argocd app sync cloudmart-dev
argocd app get cloudmart-dev
# Check: Has the GitOps repo been updated? Are manifests valid?
```

### `Connection refused` to Kubernetes API
```bash
# Verify kubeconfig
aws eks update-kubeconfig --name cloudmart-dev-eks --region us-east-1

# Check ArgoCD can reach the API
argocd cluster list
```

### Auto-sync not working
```bash
# Verify application has auto-sync enabled
argocd app get cloudmart-dev | grep "Sync Policy"
# If not: argocd app set cloudmart-dev --sync-policy automated
```

---

## Monitoring

### Prometheus targets not showing services
```bash
# Verify ServiceMonitor selector matches service labels
kubectl get servicemonitor -n monitoring
kubectl describe servicemonitor cloudmart-product-catalog -n monitoring
# Service labels must match ServiceMonitor's selector
```

### Grafana "No data" for dashboards
```bash
# Check Prometheus data source in Grafana
# Verify services expose /metrics endpoint
kubectl exec -n cloudmart-dev deploy/product-catalog -- wget -qO- http://localhost:8000/metrics
```

### Fluent Bit not shipping logs
```bash
kubectl logs -n observability daemonset/fluentbit
# Check: Are the log paths correct? Is Elasticsearch reachable?
```

### Jaeger not receiving traces
```bash
# Verify OTEL Collector is running
kubectl get pods -n observability | grep otel

# Check collector logs
kubectl logs -n observability deployment/otel-collector

# Test trace emission from a service
kubectl exec -n cloudmart-dev deploy/product-catalog -- \
    python -c "from opentelemetry import trace; trace.get_tracer('test').start_span('test').end()"
```

---

## CI/CD

### GitHub Actions: `Error: Unable to locate credentials`
**Fix:** Configure AWS OIDC properly.
```bash
# In AWS IAM, create an OIDC identity provider for GitHub
# Provider URL: https://token.actions.githubusercontent.com
# Audience: sts.amazonaws.com
# Attach role with: "Action": "sts:AssumeRoleWithWebIdentity"
```

### Trivy scan failing
```bash
# Run locally to debug
docker build -t test-service services/product-catalog
trivy image test-service --severity HIGH,CRITICAL
```

### ECR push failing
```bash
# Verify Docker is authenticated to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
```

---

## RDS Connection Issues

### "Connection refused" from pods
```bash
# Verify security group allows traffic from EKS
# Check: RDS SG should allow port 5432 from VPC CIDR (10.0.0.0/16)

# Test from within a pod
kubectl exec -n cloudmart-dev deploy/product-catalog -- \
    python -c "import asyncpg; import asyncio; \
    async def test(): \
        await asyncpg.connect('postgresql://cloudmart:PASS@HOST:5432/products'); \
    asyncio.run(test())"
```

---

## Networking

### Pods can't reach internet
```bash
# Verify NAT Gateway exists (terraform output)
# Check route table: private subnets → 0.0.0.0/0 → NAT GW
# Check EKS cluster security group allows egress
```

### Cannot access ALB
```bash
# Get ALB DNS name
kubectl get ingress cloudmart-ingress -n cloudmart-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Verify target group has healthy targets
aws elbv2 describe-target-health \
    --target-group-arn $(aws elbv2 describe-target-groups --names cloudmart --query 'TargetGroups[0].TargetGroupArn' --output text)
```
