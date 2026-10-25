# CloudMart DevOps Project - Production-Grade Microservices Platform on AWS EKS

[![CI](https://github.com/modimihir07/cloudmart-devops-project/actions/workflows/ci.yml/badge.svg)](https://github.com/modimihir07/cloudmart-devops-project/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![AWS](https://img.shields.io/badge/AWS-EKS%201.31-232F3E?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/eks/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.31-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)
[![FastAPI](https://img.shields.io/badge/FastAPI-Python%203.12-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-RDS%2016-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-ElastiCache%207-DC382D?logo=redis&logoColor=white)](https://redis.io/)
[![Prometheus](https://img.shields.io/badge/Observability-Prometheus%20%26%20Grafana-F46800?logo=prometheus&logoColor=white)](https://prometheus.io/)

CloudMart DevOps Project is an end-to-end, production-grade microservices e-commerce platform designed and built on Amazon Web Services (AWS) using Elastic Kubernetes Service (EKS 1.31). The project demonstrates modern cloud engineering, Infrastructure as Code (IaC) with Terraform, declarative GitOps deployment with ArgoCD and Kustomize, three-pillar observability (Prometheus, Grafana, EFK, Jaeger, OpenTelemetry), and fourteen strict DevSecOps security controls.

---

## Architecture Blueprint

The platform runs inside a custom AWS VPC (10.0.0.0/16) across two Availability Zones (us-east-1a and us-east-1b). Inbound client traffic terminates SSL at an AWS Application Load Balancer (ALB) and routes requests through path-based rules to Kubernetes services. Microservice workloads and data persistence instances reside strictly within private subnets.

```mermaid
graph TD
    Client(["Internet Clients<br>(HTTPS:443 / HTTP:80)"]) -->|SSL Termination| ALB["AWS Application Load Balancer (ALB)"]

    subgraph VPC ["AWS VPC (10.0.0.0/16) - Multi-AZ"]
        subgraph PublicSubnets ["Public Subnets (10.0.1.0/24 & 10.0.2.0/24)"]
            ALB
            NAT_A["NAT Gateway (AZ-a)"]
            NAT_B["NAT Gateway (AZ-b)"]
        end

        subgraph PrivateSubnets ["Private Subnets (10.0.10.0/24 & 10.0.11.0/24)"]
            subgraph EKS ["AWS EKS Cluster v1.31 (cloudmart-dev)"]
                Frontend["frontend<br>(Nginx 1.27 :8080)"]
                Products["product-catalog<br>(FastAPI :8000)"]
                Cart["cart-service<br>(FastAPI :8000)"]
                Orders["order-service<br>(FastAPI :8000)"]
                Obs["Observability Stack<br>(Prometheus / Grafana / Fluent Bit / Jaeger)"]
            end
        end

        subgraph DBSubnets ["Isolated Database Subnets (10.0.20.0/24 & 10.0.21.0/24)"]
            RDS_Prod[("RDS PostgreSQL<br>products_db (5432)")]
            Redis_Cart[("ElastiCache Redis<br>cart (6379)")]
            RDS_Order[("RDS PostgreSQL<br>orders_db (5432)")]
        end
    end

    ALB -->|Path: /| Frontend
    ALB -->|Path: /api/products| Products
    ALB -->|Path: /api/cart| Cart
    ALB -->|Path: /api/orders| Orders

    Products -->|asyncpg| RDS_Prod
    Cart -->|redis-py| Redis_Cart
    Orders -->|asyncpg| RDS_Order

    NAT_A -.->|Outbound Egress| EKS
    NAT_B -.->|Outbound Egress| EKS
```

### Architecture Topology Flow

```text
=============================================================================
                       CLOUD ARCHITECTURE TOPOLOGY
=============================================================================

Internet Inbound Traffic (HTTPS:443 / HTTP:80)
       │
       ▼
[ AWS VPC: 10.0.0.0/16 ] ────────────────────────────────────────────────────
       │
       ├── PUBLIC SUBNETS (10.0.1.0/24 & 10.0.2.0/24 - Multi-AZ)
       │     └── AWS Application Load Balancer (ALB) - SSL & Path Routing
       │           ├── Path: /             ──► frontend (Nginx 1.27 :8080)
       │           ├── Path: /api/products ──► product-catalog (FastAPI :8000)
       │           ├── Path: /api/cart     ──► cart-service (FastAPI :8000)
       │           └── Path: /api/orders   ──► order-service (FastAPI :8000)
       │
       ├── PRIVATE SUBNETS (10.0.10.0/24 & 10.0.11.0/24 - Multi-AZ)
       │     ├── AWS EKS Managed Cluster (v1.31) - Namespace: cloudmart-dev
       │     │     ├── Worker Nodes: Amazon Linux 2023 / Containerd
       │     │     ├── Ingress Routing: AWS Load Balancer Controller
       │     │     └── Security Context: Non-Root (UID 10001), Read-Only Root FS
       │     │
       │     ├── Observability Stack:
       │     │     ├── Metrics: Prometheus Agent (RED Scrape) & Grafana
       │     │     ├── Logging: Fluent Bit DaemonSet ──► Elasticsearch / Kibana
       │     │     └── Tracing: OpenTelemetry SDK ──► Jaeger (OTLP Distributed)
       │     │
       │     └── Zero-Trust Security:
       │           └── Calico NetworkPolicies (Default-Deny Ingress / Egress)
       │
       └── ISOLATED DATABASE SUBNETS (10.0.20.0/24 & 10.0.21.0/24)
             ├── product-catalog ──► RDS PostgreSQL (Port 5432, KMS Encrypted)
             ├── cart-service    ──► ElastiCache Redis Cluster (Port 6379, TLS)
             └── order-service   ──► RDS PostgreSQL (Port 5432, KMS Encrypted)
=============================================================================
```

---

## Technical Specifications

| Component | Technology | Version | Purpose |
|---|---|---|---|
| Cloud Provider | Amazon Web Services (AWS) | Cloud | Core hosting and managed services |
| Container Orchestration | Amazon EKS | 1.31 | Kubernetes cluster management and node groups |
| Infrastructure as Code | Terraform | ~5.0 | Modular infrastructure (VPC, EKS, RDS, Redis, IAM) |
| Programming Runtime | Python | 3.12 | Microservices backend implementation |
| Web Framework | FastAPI | 0.115 | High-performance asynchronous REST APIs |
| Web Server / Proxy | Nginx Alpine | 1.27 | Static frontend server and internal reverse proxy |
| Relational Databases | Amazon RDS PostgreSQL | 16 | Dedicated instances for products and orders |
| In-Memory Cache | Amazon ElastiCache Redis | 7.1 | Session storage and rapid shopping cart retrieval |
| Continuous Integration | GitHub Actions | Latest | Multi-stage pipeline: lint, test, CodeQL, Trivy, ECR |
| Continuous Delivery | ArgoCD + Kustomize | Latest | Declarative GitOps deployment with dev and prod overlays |
| Metrics & Monitoring | Prometheus + Grafana | Latest | RED metrics, ServiceMonitors, custom alert rules |
| Log Aggregation | Fluent Bit + Elasticsearch + Kibana | 8.16 | Centralized log ingestion, parsing, and analysis |
| Distributed Tracing | OpenTelemetry + Jaeger | Latest | Distributed request tracing with OTLP standard |
| Incident Management | AWS SNS + Lambda + PagerDuty | Serverless | Automated alerting and on-call notification |

---

## Repository Structure

```
cloudmart-devops-project/
├── .github/workflows/
│   ├── ci.yml                       # Matrix CI: lint, unit test, CodeQL, Trivy, ECR push
│   └── cd.yml                       # Manual trigger workflow with rollout verification
├── services/
│   ├── frontend/                    # Single-page UI, Nginx reverse proxy, static assets
│   ├── product-catalog/             # Catalog service: FastAPI, asyncpg, PostgreSQL
│   ├── cart-service/                # Cart service: FastAPI, Redis session storage
│   └── order-service/               # Order service: FastAPI, asyncpg, JSON order tracking
├── terraform/
│   ├── modules/                     # Reusable modules: vpc, eks, rds, elasticache, iam
│   └── live/dev/                    # Dev environment configuration and state definition
├── k8s-manifests/
│   ├── base/                        # Deployments, Services, HPA, PDB, Ingress, NetPols
│   └── overlays/
│       ├── dev/                     # Dev overlay: single replica, light requests
│       └── prod/                    # Prod overlay: 3 replicas, HPA 2-10, strict limits
├── argocd/
│   ├── project.yaml                 # ArgoCD Project boundaries and source whitelist
│   ├── dev-app.yaml                 # Dev Application manifest with auto-sync and prune
│   └── prod-app.yaml                # Prod Application manifest
├── monitoring/
│   ├── prometheus/                  # ServiceMonitors and alerting rules
│   ├── grafana/dashboards/          # CloudMart service overview dashboard
│   ├── logging/                     # Fluent Bit DaemonSet and Elasticsearch configs
│   └── tracing/                     # OpenTelemetry Collector and Jaeger all-in-one
├── scripts/
│   ├── backup-rds.sh                # Automated encrypted RDS dumps shipped to S3
│   ├── health-check.sh              # Deep health probe verifying cluster and backends
│   ├── simulate-alarm.sh            # End-to-end alert verification to PagerDuty
│   └── lambda/                      # CloudWatch/SNS to PagerDuty incident forwarder
├── docker-compose.yml               # Complete local multi-container development stack
├── Makefile                         # Unified operations helper commands
├── LICENSE                          # MIT License
├── INSTRUCTIONS.md                  # Comprehensive AWS deployment walkthrough
└── DEMO-GUIDE.md                    # Structured live demonstration manual
```

---

## DevSecOps and Security Posture

CloudMart DevOps Project embeds security into every layer of the architecture:

1. **Pod Security Standards (PSS):** The `cloudmart-dev` namespace is labeled with `pod-security.kubernetes.io/enforce: restricted`. All containers run as non-root (UID 1001), have a read-only root filesystem with scoped `emptyDir` mounts, drop all Linux capabilities (`capabilities.drop: ["ALL"]`), and enforce the `RuntimeDefault` seccomp profile.
2. **Network Segmentation:** Kubernetes NetworkPolicies enforce a strict default-deny posture for both ingress and egress. Only explicitly allowed communications can occur (for example, frontend can only access services on port 8000; catalog and order services can only egress to port 5432; cart service can only egress to port 6379).
3. **Identity and Access Management (IRSA):** Pods use AWS IAM Roles for Service Accounts (IRSA) with OpenID Connect (OIDC). Containers do not require stored AWS credentials or static access keys.
4. **Secret Management:** Sensitive credentials (database passwords, Redis AUTH tokens) are generated using Terraform `random_password` and stored in AWS Secrets Manager. Secrets are never stored in git or environment files.
5. **Static and Container Security Scanning:** Every pull request runs CodeQL for Static Application Security Testing (SAST) and Aqua Trivy for filesystem and container image vulnerability scanning.
6. **Data Encryption:** PostgreSQL instances, ElastiCache Redis, and S3 asset/backup buckets utilize AWS KMS customer-managed keys for encryption at rest. All inter-service Redis traffic uses transit encryption (TLS).

---

## Local Development and Verification

You can run and test the complete microservices stack locally using Docker Compose without needing AWS resources.

### Prerequisites

- Docker and Docker Compose v2+
- Python 3.12+ (or `uv` package runner)
- `curl` and `git`

### 1. Launch the Stack

```bash
# Clone the repository
git clone https://github.com/modimihir07/cloudmart-devops-project.git
cd cloudmart-devops-project

# Start all containers in the background
docker compose up -d
```

Docker Compose spins up:
- PostgreSQL (Products) on port 5433
- PostgreSQL (Orders) on port 5434
- Redis on port 6379
- Product Catalog on port 8001
- Cart Service on port 8002
- Order Service on port 8003
- Frontend (Nginx) on port 8080

### 2. Access the Web Application

Open your browser to `http://localhost:8080`.
- Browse products retrieved dynamically from the product catalog.
- Add items to your cart (stored under your unique session in Redis).
- Open the Cart modal and click **Place Order** to create an immutable order record in PostgreSQL.
- View recent transactions under **Orders**.

### 3. Run Automated Unit Tests

All services include comprehensive, isolated unit tests with mock database and cache fixtures:

```bash
# Run tests for all services
cd services/frontend && python -m pytest tests/ -v
cd ../product-catalog && python -m pytest tests/ -v
cd ../cart-service && python -m pytest tests/ -v
cd ../order-service && python -m pytest tests/ -v
```

All 18 unit tests validate API endpoints, Prometheus metrics export (`/metrics`), health probes, and session interactions.

---

## AWS Deployment Summary

Deploying CloudMart DevOps Project to AWS involves four main stages:

### Stage 1: Infrastructure Provisioning with Terraform

```bash
cd terraform/live/dev
terraform init
terraform plan
terraform apply -auto-approve
```

This provisions the VPC, Internet Gateway, NAT Gateways, EKS Cluster with managed node groups, two RDS PostgreSQL instances, ElastiCache Redis, S3 buckets, and IAM roles.

### Stage 2: Configure Kubernetes Access and Secrets

```bash
# Configure local kubeconfig
aws eks update-kubeconfig --name cloudmart-dev-eks --region us-east-1

# Create dev namespace
kubectl create namespace cloudmart-dev

# Populate database connection secrets from Terraform outputs
kubectl create secret generic cloudmart-db-secrets \
    -n cloudmart-dev \
    --from-literal=products-database-url="postgresql://cloudmart:PASSWORD@products.rds.us-east-1.amazonaws.com:5432/products" \
    --from-literal=orders-database-url="postgresql://cloudmart:PASSWORD@orders.rds.us-east-1.amazonaws.com:5432/orders" \
    --from-literal=redis-url="redis://PASSWORD@redis.cache.us-east-1.amazonaws.com:6379"
```

### Stage 3: Install Observability Stack

```bash
# Install Prometheus and Grafana via Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Apply CloudMart ServiceMonitors and Alerting Rules
kubectl apply -f monitoring/prometheus/
kubectl apply -f monitoring/grafana/dashboards/

# Apply Jaeger and OpenTelemetry Collector
kubectl apply -f monitoring/tracing/

# Apply EFK Stack
kubectl apply -f monitoring/logging/
```

### Stage 4: Deploy Workloads via GitOps (ArgoCD)

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply CloudMart ArgoCD Application
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/dev-app.yaml
```

ArgoCD continuously monitors your GitOps repository, applies the Kustomize manifests, and reconciles state automatically.

For step-by-step instructions including tear-down procedures, consult [INSTRUCTIONS.md](INSTRUCTIONS.md) and [DEMO-GUIDE.md](DEMO-GUIDE.md).

---

## Observability and Alerting

The observability stack tracks metrics, logs, and distributed traces across all microservices:

- **Metrics (Prometheus):** Every backend microservice exposes Prometheus metrics on `/metrics`, measuring `http_requests_total` and `http_request_duration_seconds`. ServiceMonitors scrape targets every 15 seconds.
- **Visualizations (Grafana):** A pre-configured dashboard displays request rates, 95th percentile latency, HTTP 5xx error percentages, and container CPU/memory utilization.
- **Logging (Fluent Bit + Elasticsearch + Kibana):** Container logs are streamed in real time from `/var/log/containers` through Fluent Bit, parsed into JSON, indexed in Elasticsearch, and searchable in Kibana.
- **Tracing (OpenTelemetry + Jaeger):** Inbound HTTP requests and outbound database queries generate trace spans exported via OTLP gRPC to the OpenTelemetry Collector and visualized in the Jaeger UI.
- **Incident Simulation:** Run `./scripts/simulate-alarm.sh` to trigger an incident through CloudWatch, forward the alert through an SNS topic to an AWS Lambda function, and trigger a PagerDuty on-call notification.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Author & Architecture Lead

**Mihir Modi**
- GitHub: [@modimihir07](https://github.com/modimihir07)
- Project: CloudMart DevOps Project
- Specialization: Cloud-Native Microservices Architecture & DevSecOps Platform
