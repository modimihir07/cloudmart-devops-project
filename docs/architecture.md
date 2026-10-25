# CloudMart DevOps Project - Architecture

> **Made by Mihir Modi** - DevOps Capstone Project

## System Architecture

```
                            ┌──────────────────────────┐
                            │     Internet / Users      │
                            └────────────┬─────────────┘
                                         │
                                         ▼
                            ┌──────────────────────────┐
                            │   AWS ALB (Ingress)       │
                            │   HTTP:80 (nip.io)        │
                            └────────────┬─────────────┘
                                         │
                    ┌────────────────────┴────────────────────┐
                    │            EKS Cluster                  │
                    │       cloudmart-dev-eks (1.31)          │
                    │                                          │
                    │  ┌──────────────┐  ┌────────────────┐   │
                    │  │  Frontend    │  │  Cart Service  │   │
                    │  │  Nginx:8080  │  │  FastAPI:8000  │   │
                    │  └──────┬───────┘  └───────┬────────┘   │
                    │         │                   │            │
                    │         ▼                   │ (Redis)    │
                    │  ┌──────────────┐           │            │
                    │  │   Product    │◄──────────┘            │
                    │  │   Catalog    │                        │
                    │  │  FastAPI:8000│                        │
                    │  └──────┬───────┘                        │
                    │         │                                │
                    │         ▼                                │
                    │  ┌──────────────┐                        │
                    │  │    Order     │                        │
                    │  │   Service    │                        │
                    │  │  FastAPI:8000│                        │
                    │  └──────────────┘                        │
                    └──────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                    AWS Managed Services                        │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐    │
│  │  RDS x2      │  │  ElastiCache │  │  ECR (4 repos)    │    │
│  │  PostgreSQL  │  │  Redis 7     │  │  Image registry   │    │
│  │  db.t4g.micro│  │  t4g.micro   │  │                   │    │
│  └──────────────┘  └──────────────┘  └───────────────────┘    │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐    │
│  │  S3 x2       │  │  Secrets Mgr │  │  KMS              │    │
│  │  Static+Bakup │  │  + IRSA      │  │  Encryption keys │    │
│  └──────────────┘  └──────────────┘  └───────────────────┘    │
└────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Browse Products
```
User → ALB → Frontend(Nginx) → /api/products → Product Service → RDS(products)
                                                              → Return JSON list
                                                              → Frontend renders HTML
```

### Add to Cart
```
User → ALB → Frontend → /api/cart/items POST → Cart Service → Redis(cart:{session})
                                     ← Return updated cart items
```

### Place Order
```
User → ALB → Frontend → /api/orders POST → Order Service → RDS(orders)
                        → Cart Service → Clear cart from Redis
                        ← Return order confirmation
```

---

## Network Architecture

```
AWS Region: us-east-1
├── VPC: 10.0.0.0/16
│   ├── Public Subnet A: 10.0.1.0/24 (us-east-1a)
│   │   └── NAT Gateway
│   ├── Public Subnet B: 10.0.2.0/24 (us-east-1b)
│   │   └── Internet Gateway
│   ├── Private Subnet A: 10.0.10.0/24 (us-east-1a)
│   │   ├── EKS node group
│   │   ├── RDS (products)
│   │   └── ElastiCache Redis
│   └── Private Subnet B: 10.0.11.0/24 (us-east-1b)
│       ├── EKS node group
│       ├── RDS (orders)
│       └── ElastiCache Redis (replica)
```

---

## CI/CD Pipeline Architecture

```
Developer pushes to main
         │
         ▼
┌─────────────────────┐
│  GitHub Actions     │
│                     │
│  ┌───────────────┐  │
│  │ Lint + Test   │  │  flake8, black, pytest
│  └───────┬───────┘  │
│  ┌───────┴───────┐  │
│  │ CodeQL (SAST) │  │  Security & quality queries
│  └───────┬───────┘  │
│  ┌───────┴───────┐  │
│  │ Trivy Scan    │  │  Container vulnerabilities
│  └───────┬───────┘  │
│  ┌───────┴───────┐  │
│  │ Build + Push  │  │  → ECR (SHA tag + latest)
│  └───────┬───────┘  │
│  ┌───────┴───────┐  │
│  │ Update GitOps │  │  → cloudmart-devops-project-gitops repo
│  └───────────────┘  │
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│  ArgoCD             │
│  Auto-sync detect   │
│  Self-heal enabled  │
│  Prune resources    │
│                     │
│  ┌───────────────┐  │
│  │ Deploy to EKS │  │
│  │ Apply overlay │  │  → cloudmart-dev namespace
│  └───────────────┘  │
└─────────────────────┘
```

---

## Security Architecture

### Defense in Depth

| Layer | Control | What It Prevents |
|-------|---------|-----------------|
| **Network** | Private subnets for workloads | Direct internet access to services |
| **Network** | Security groups (least privilege) | Unauthorized port access |
| **Network** | NetworkPolicies (default deny) | Lateral pod-to-pod movement |
| **Pod** | SecurityContext (non-root, read-only FS, drop caps) | Container breakout |
| **Pod** | seccomp (RuntimeDefault) | System call abuse |
| **Pod** | Resource limits | DoS through resource exhaustion |
| **K8s** | Pod Security Standards (restricted) | Privileged pods |
| **IAM** | IRSA per service | AWS API access limited to each service's needs |
| **Secrets** | AWS Secrets Manager | No secrets in Git or pods |
| **Data** | Encryption at rest (KMS) | Data breach if storage is compromised |
| **Data** | Encrypted backups | Backup compromise |
| **CI/CD** | Trivy scan (fail on HIGH/CRITICAL) | Vulnerable images deployed |
| **CI/CD** | CodeQL | Code-level vulnerabilities |
| **K8s** | PodDisruptionBudget | Availability during updates |

### IRSA (IAM Roles for Service Accounts)

Each microservice gets its own IAM role with minimal permissions:

| Service Account | IAM Permissions |
|----------------|-----------------|
| `product-catalog` | `secretsmanager:GetSecretValue` (product DB secret) |
| `cart-service` | `secretsmanager:GetSecretValue` (Redis secret) |
| `order-service` | `secretsmanager:GetSecretValue` (order DB secret) |
| `frontend` | `secretsmanager:GetSecretValue`, `s3:GetObject` (static assets) |

---

## Observability Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenTelemetry Pipeline                    │
│                                                             │
│  Service ──OTLP──► OTEL Collector ───► Jaeger (Traces)      │
│                    │                                        │
│                    ├──► Prometheus (Metrics)                 │
│                    │        │                                │
│                    │        ├──► Grafana (Dashboards)       │
│                    │        └──► Alertmanager                │
│                    │              │                          │
│                    │              └──► SNS ──► Lambda        │
│                    │                         └──► PagerDuty  │
│                    │                                        │
│                    └──► Fluent Bit ──► ES ──► Kibana (Logs)  │
└─────────────────────────────────────────────────────────────┘
```
