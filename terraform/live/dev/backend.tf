terraform {
  backend "s3" {
    bucket         = "cloudmart-devops-project-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "cloudmart-devops-project-tfstate-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  required_version = ">= 1.7"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "CloudMart-DevOps-Project"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
