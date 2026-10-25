# ─── CloudMart DevOps Project - Dev Environment Variables ───
# REPLACE these values with your own before deploying.

region                = "us-east-1"
environment           = "dev"
vpc_cidr              = "10.0.0.0/16"
availability_zones    = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
# EKS endpoint public access CIDR (Restrict to your trusted management IP in production, e.g. ["YOUR_IP/32"])
eks_public_access_cidrs = ["0.0.0.0/0"]
