.PHONY: help build test clean docker-build docker-push deploy-dev deploy-prod destroy

SERVICE ?= frontend
ENV ?= dev

help:
	@echo "CloudMart DevOps Project - Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make build SERVICE=<name>     Build Docker image for a service"
	@echo "  make test SERVICE=<name>      Run unit tests for a service"
	@echo "  make docker-build             Build all Docker images locally"
	@echo "  make deploy-dev               Deploy to dev with kustomize"
	@echo "  make terraform-apply          Apply terraform"
	@echo "  make terraform-destroy        Destroy terraform"
	@echo "  make clean                    Clean build artifacts"

build:
	docker build -t cloudmart/$(SERVICE):latest services/$(SERVICE)

test:
	cd services/$(SERVICE) && python -m pytest tests/ -v

docker-build:
	@for service in frontend product-catalog cart-service order-service; do \
		echo "Building $$service..."; \
		docker build -t cloudmart/$$service:latest services/$$service; \
	done

deploy-dev:
	kubectl apply -k k8s-manifests/overlays/dev/

deploy-prod:
	kubectl apply -k k8s-manifests/overlays/prod/

terraform-init:
	cd terraform/live/dev && terraform init

terraform-plan:
	cd terraform/live/dev && terraform plan

terraform-apply:
	cd terraform/live/dev && terraform apply -auto-approve

terraform-destroy:
	cd terraform/live/dev && terraform destroy -auto-approve

clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name '*.pyc' -delete
