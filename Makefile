# Nuxeo Kubernetes Stack - Makefile
# Automated deployment and management for multi-environment Kubernetes infrastructure

.PHONY: help install-tools install-staging-ca validate-dev validate-stage validate-prod validate-all
.PHONY: secrets create-secrets check-secrets check-env-dev check-env-stage check-env-prod check-env-all 
.PHONY: deploy-dev deploy-stage deploy-prod
.PHONY: deploy-infra-dev deploy-infra-stage deploy-infra-prod deploy-infra-dev-docker
.PHONY: deploy-projects-dev deploy-projects-stage deploy-projects-prod
.PHONY: install-nginx-gateway install-nginx-ingress install-metallb
.PHONY: delete-dev delete-stage delete-prod delete-projects-dev delete-projects-stage delete-infra-stage delete-projects-prod clean-all clean-kafka-data
.PHONY: status logs port-forward restart-infra restart-namespace get-elastic-password
.PHONY: drain-node uncordon-node

#═══════════════════════════════════════════════════════════════════════════════
# QUICK START GUIDE
#═══════════════════════════════════════════════════════════════════════════════
# 1. Create secrets:        make create-secrets
# 2. Validate config:       make validate-prod
# 3. Deploy infrastructure: make deploy-infra-prod
# 4. Check status:          make status
# 
# For complete documentation, see README.md
#═══════════════════════════════════════════════════════════════════════════════

# Variables
KUBECTL := kubectl
KUSTOMIZE := $(KUBECTL) kustomize

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "════════════════════════════════════════════════════════════════════════════════"
	@echo "  $(BLUE)Nuxeo Kubernetes Stack - Available Commands$(NC)"
	@echo "════════════════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "$(GREEN)📋 Quick Start:$(NC)"
	@echo "  make create-secrets      → Generate secret template files"
	@echo "  make validate-prod       → Validate production configuration"
	@echo "  make deploy-infra-prod   → Deploy infrastructure to production"
	@echo "  make status              → Check deployment status"
	@echo ""
	@echo "$(GREEN)📦 Setup & Prerequisites:$(NC)"
	@echo "  make install-tools       - Install required tools (kubectl, kustomize)"
	@echo "  make install-staging-ca  - Install Let's Encrypt staging CA locally (macOS)"
	@echo "  make create-secrets      - Create all secret files from samples"
	@echo "  make check-secrets       - Verify all required secrets exist"
	@echo "  make check-env-dev       - Verify dev overlay environment files"
	@echo "  make check-env-stage     - Verify stage overlay environment files"
	@echo "  make check-env-prod      - Verify prod overlay environment files"
	@echo "  make check-env-all       - Verify all overlay environment files"
	@echo ""
	@echo "$(GREEN)✅ Validation:$(NC)"
	@echo "  make validate-dev        - Validate dev environment kustomization"
	@echo "  make validate-stage      - Validate stage environment kustomization"
	@echo "  make validate-prod       - Validate prod environment kustomization"
	@echo "  make validate-all        - Validate all environments"
	@echo ""
	@echo "$(GREEN)🚀 Deployment:$(NC)"
	@echo "  make deploy-infra-dev    - Deploy only infrastructure (dev)"
	@echo "  make deploy-infra-dev-docker - Deploy only infrastructure (dev) using Docker"
	@echo "  make deploy-infra-stage  - Deploy only infrastructure (stage)"
	@echo "  make deploy-infra-prod   - Deploy only infrastructure (prod)"
	@echo "  make deploy-dev          - Deploy complete dev environment (infra + projects)"
	@echo "  make deploy-stage        - Deploy complete stage environment"
	@echo "  make deploy-prod         - Deploy complete prod environment"
	@echo "  make deploy-projects-dev - Deploy only projects (dev)"
	@echo ""
	@echo "$(GREEN)📊 Status & Monitoring:$(NC)"
	@echo "  make status              - Show status of all pods across namespaces"
	@echo "  make logs NS=<namespace> - Show logs for namespace (e.g., make logs NS=jenkins)"
	@echo "  make port-forward        - Setup port forwarding for dev services"
	@echo "  make get-elastic-password - Get the Elasticsearch elastic user password"
	@echo "  make check-monitoring    - Check monitoring stack (Prometheus/Grafana) status"
	@echo "  make restart-infra       - Restart all infrastructure workloads"
	@echo "  make restart-namespace NS=<namespace> - Restart workloads in specific namespace"
	@echo ""
	@echo "$(GREEN)🧹 Cleanup:$(NC)"
	@echo "  make delete-dev          - Delete dev environment"
	@echo "  make delete-projects-dev - Delete only dev projects (keep infra)"
	@echo "  make delete-stage        - Delete stage environment"
	@echo "  make delete-projects-stage - Delete only stage projects (keep infra)"
	@echo "  make delete-infra-stage  - Delete only stage infrastructure (keep projects)"
	@echo "  make delete-prod         - Delete prod environment"
	@echo "  make delete-projects-prod - Delete only prod projects (keep infra)"
	@echo "  make clean-all           - Delete everything (WARNING: data loss!)"
	@echo "  make clean-kafka-data    - Fix Kafka cluster ID mismatch (WARNING: data loss!)"
	@echo ""
	@echo "$(GREEN)🔧 Utilities:$(NC)"
	@echo "  make drain-node NODE=<name> - Drain a node for maintenance"
	@echo "  make uncordon-node NODE=<name> - Re-enable scheduling on node"
	@echo ""
	@echo "════════════════════════════════════════════════════════════════════════════════"
	@echo "  Environment Variables:"
	@echo "    NS      - Namespace for logs/debug commands (e.g., NS=kafka)"
	@echo "    NODE    - Node name for drain/uncordon operations"
	@echo ""
	@echo "  Examples:"
	@echo "    make logs NS=kafka"
	@echo "    make drain-node NODE=k8s-worker2"
	@echo "════════════════════════════════════════════════════════════════════════════════"
	@echo ""

#═══════════════════════════════════════════════════════════════════════════════
# PREREQUISITES & SETUP
#═══════════════════════════════════════════════════════════════════════════════
install-tools: ## Install kubectl and verify setup
	@echo "$(BLUE)Checking required tools...$(NC)"
	@which kubectl > /dev/null || (echo "$(RED)kubectl not found. Install from: https://kubernetes.io/docs/tasks/tools/$(NC)" && exit 1)
	@echo "$(GREEN)✓ kubectl found: $$(kubectl version --client --short 2>/dev/null)$(NC)"
	@kubectl cluster-info > /dev/null 2>&1 || (echo "$(RED)Cannot connect to Kubernetes cluster$(NC)" && exit 1)
	@echo "$(GREEN)✓ Connected to cluster: $$(kubectl config current-context)$(NC)"
	@echo "$(GREEN)✓ All tools ready!$(NC)"

install-staging-ca: ## Install Let's Encrypt staging CA locally (macOS)
	@echo "$(BLUE)Installing Let's Encrypt staging CA certificate...$(NC)"
	@echo "$(YELLOW)Downloading staging CA certificate...$(NC)"
	@curl -s -o /tmp/letsencrypt-stg-root-x1.pem https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x1.pem
	@echo "$(YELLOW)Adding to system keychain (requires sudo password)...$(NC)"
	@sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/letsencrypt-stg-root-x1.pem
	@echo "$(GREEN)✓ Let's Encrypt staging CA installed. Restart browsers to take effect.$(NC)"


check-secrets: ## Verify all required secret files exist
	@echo "$(BLUE)Checking for required secret files...$(NC)"
	@missing=0; \
	 for secret in infra/base/mongo/.env.mongo.secret \
				  infra/base/postgres/.env.postgres.secret \
				  infra/base/redis/.env.redis.secret \
				  infra/base/minio/.env.minio.secret \
				  infra/base/sftp/.env.sftp.secret \
				  infra/base/keycloak/.env.keycloak.secret \
				  infra/base/gitlab/.env.gitlab.secret \
				  projects/base/nuxeo/.env.nuxeo.secret.sample; do \
		if [ ! -f "$$secret" ]; then \
			echo "$(RED)✗ Missing: $$secret$(NC)"; \
			missing=$$((missing + 1)); \
		else \
			echo "$(GREEN)✓ Found: $$secret$(NC)"; \
		fi; \
	done; \
	if [ $$missing -gt 0 ]; then \
		echo "$(YELLOW)Run 'make create-secrets' to create missing files$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)✓ All required secrets exist$(NC)"; \
	fi

check-env-dev: ## Verify all dev overlay env files exist
	@echo "$(BLUE)Checking dev overlay environment files...$(NC)"
	@missing=0; \
	 for env in infra/overlays/dev/elasticsearch/.env.elasticsearch \
				infra/overlays/dev/gitlab/.env.gitlab \
				infra/overlays/dev/jenkins/.env.jenkins \
				infra/overlays/dev/kafka/.env.kafka \
				infra/overlays/dev/keycloak/.env.keycloak \
				infra/overlays/dev/mailhog/.env.mailhog \
				infra/overlays/dev/minio/.env.minio \
				infra/overlays/dev/mongo/.env.mongo \
				infra/overlays/dev/monitoring/.env.monitoring \
				infra/overlays/dev/postgres/.env.postgres \
				infra/overlays/dev/redis/.env.redis \
				projects/overlays/dev/acme-nuxeo23/.env.nuxeo.secret \
				projects/overlays/dev/acme-nuxeo23/.env.nuxeo \
				projects/overlays/dev/acme-nuxeo25/.env.nuxeo.secret \
				projects/overlays/dev/acme-nuxeo25/.env.nuxeo; do \
		if [ ! -f "$$env" ]; then \
			echo "$(RED)✗ Missing: $$env$(NC)"; \
			missing=$$((missing + 1)); \
		else \
			echo "$(GREEN)✓ Found: $$env$(NC)"; \
		fi; \
	done; \
	if [ $$missing -gt 0 ]; then \
		echo "$(YELLOW)⚠  Missing $$missing dev environment file(s)$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)✓ All dev environment files exist$(NC)"; \
	fi

check-env-stage: ## Verify all stage overlay env files exist
	@echo "$(BLUE)Checking stage overlay environment files...$(NC)"
	@missing=0; \
	 for env in infra/overlays/stage/elasticsearch/.env.elastic \
				infra/overlays/stage/gitlab/.env.gitlab \
				infra/overlays/stage/jenkins/.env.jenkins \
				infra/overlays/stage/kafka/.env.kafka \
				infra/overlays/stage/keycloak/.env.keycloak \
				infra/overlays/stage/mailhog/.env.mailhog \
				infra/overlays/stage/minio/.env.minio \
				infra/overlays/stage/mongo/.env.mongo \
				infra/overlays/stage/monitoring/.env.monitoring \
				infra/overlays/stage/postgres/.env.postgres \
				infra/overlays/stage/redis/.env.redis \
				projects/overlays/stage/acme-nuxeo23/.env.nuxeo.secret \
				projects/overlays/stage/acme-nuxeo23/.env.nuxeo \
				projects/overlays/stage/acme-nuxeo25/.env.nuxeo.secret \
				projects/overlays/stage/acme-nuxeo25/.env.nuxeo; do \
		if [ ! -f "$$env" ]; then \
			echo "$(RED)✗ Missing: $$env$(NC)"; \
			missing=$$((missing + 1)); \
		else \
			echo "$(GREEN)✓ Found: $$env$(NC)"; \
		fi; \
	done; \
	if [ $$missing -gt 0 ]; then \
		echo "$(YELLOW)⚠  Missing $$missing stage environment file(s)$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)✓ All stage environment files exist$(NC)"; \
	fi

check-env-prod: ## Verify all prod overlay env files exist
	@echo "$(BLUE)Checking prod overlay environment files...$(NC)"
	@missing=0; \
	 for env in infra/overlays/prod/elasticsearch/.env.elastic \
				infra/overlays/prod/gitlab/.env.gitlab \
				infra/overlays/prod/kafka/.env.kafka \
				infra/overlays/prod/keycloak/.env.keycloak \
				infra/overlays/prod/mailhog/.env.mailhog \
				infra/overlays/prod/minio/.env.minio \
				infra/overlays/prod/mongo/.env.mongo \
				infra/overlays/prod/monitoring/.env.monitoring \
				infra/overlays/prod/postgres/.env.postgres \
				infra/overlays/prod/redis/.env.redis \
				projects/overlays/prod/acme-nuxeo23/.env.nuxeo.secret \
				projects/overlays/prod/acme-nuxeo23/.env.nuxeo \
				projects/overlays/prod/acme-nuxeo25/.env.nuxeo.secret \
				projects/overlays/prod/acme-nuxeo25/.env.nuxeo; do \
		if [ ! -f "$$env" ]; then \
			echo "$(RED)✗ Missing: $$env$(NC)"; \
			missing=$$((missing + 1)); \
		else \
			echo "$(GREEN)✓ Found: $$env$(NC)"; \
		fi; \
	done; \
	if [ $$missing -gt 0 ]; then \
		echo "$(YELLOW)⚠  Missing $$missing prod environment file(s)$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)✓ All prod environment files exist$(NC)"; \
	fi

check-env-all: check-env-dev check-env-stage check-env-prod ## Verify all overlay env files for all environments
	@echo "$(GREEN)✓ All environment files validated across dev, stage, and prod$(NC)"

#═══════════════════════════════════════════════════════════════════════════════
# VALIDATION
#═══════════════════════════════════════════════════════════════════════════════
validate-dev: ## Validate dev environment kustomization
	@echo "$(BLUE)Validating dev environment...$(NC)"
	@$(KUSTOMIZE) infra/overlays/dev > /dev/null && echo "$(GREEN)✓ infra/overlays/dev$(NC)" || (echo "$(RED)✗ infra/overlays/dev$(NC)" && exit 1)
	@$(KUSTOMIZE) projects/overlays/dev > /dev/null && echo "$(GREEN)✓ projects/overlays/dev$(NC)" || (echo "$(RED)✗ projects/overlays/dev$(NC)" && exit 1)
	@echo "$(GREEN)✓ Dev environment validation passed$(NC)"

validate-stage: ## Validate stage environment kustomization
	@echo "$(BLUE)Validating stage environment...$(NC)"
	@$(KUSTOMIZE) infra/overlays/stage > /dev/null && echo "$(GREEN)✓ infra/overlays/stage$(NC)" || (echo "$(RED)✗ infra/overlays/stage$(NC)" && exit 1)
	@$(KUSTOMIZE) projects/overlays/stage > /dev/null && echo "$(GREEN)✓ projects/overlays/stage$(NC)" || (echo "$(RED)✗ projects/overlays/stage$(NC)" && exit 1)
	@echo "$(GREEN)✓ Stage environment validation passed$(NC)"

validate-prod: ## Validate prod environment kustomization
	@echo "$(BLUE)Validating prod environment...$(NC)"
	@$(KUSTOMIZE) infra/overlays/prod > /dev/null && echo "$(GREEN)✓ infra/overlays/prod$(NC)" || (echo "$(RED)✗ infra/overlays/prod$(NC)" && exit 1)
	@$(KUSTOMIZE) projects/overlays/prod > /dev/null && echo "$(GREEN)✓ projects/overlays/prod$(NC)" || (echo "$(RED)✗ projects/overlays/prod$(NC)" && exit 1)
	@echo "$(GREEN)✓ Prod environment validation passed$(NC)"

validate-all: ## Validate all environments
	@echo "$(BLUE)Validating all environments...$(NC)"
	@$(MAKE) validate-dev
	@$(MAKE) validate-stage
	@$(MAKE) validate-prod
	@echo "$(GREEN)✓ All environments validated successfully$(NC)"

#═══════════════════════════════════════════════════════════════════════════════
# GATEWAY & CONTROLLER INSTALLATION
#═══════════════════════════════════════════════════════════════════════════════
install-cert-manager: ## Install cert-manager
	@echo "$(BLUE)Checking cert-manager installation...$(NC)"
	@if $(KUBECTL) get namespace cert-manager >/dev/null 2>&1; then \
		echo "$(YELLOW)cert-manager already installed, waiting for readiness...$(NC)"; \
	else \
		echo "$(BLUE)Installing cert-manager...$(NC)"; \
		$(KUBECTL) apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml; \
	fi
	@echo "$(BLUE)Waiting for cert-manager to be ready...$(NC)"
	@$(KUBECTL) wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s
	@echo "$(GREEN)✓ cert-manager ready$(NC)"


install-nginx-gateway: ## Install NGINX Gateway Fabric
	@echo "$(BLUE)Installing NGINX Gateway Fabric...$(NC)"
	@echo "$(YELLOW)Installing NGINX Gateway Fabric CRDs...$(NC)"
	@$(KUBECTL) apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v2.3.0/deploy/crds.yaml --server-side=true --force-conflicts
	@echo "$(YELLOW)Applying Gateway API CRDs...$(NC)"
	@$(KUBECTL) apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
	@echo "$(YELLOW)Installing NGINX Gateway Fabric...$(NC)"
	@$(KUBECTL) apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v2.3.0/deploy/default/deploy.yaml
	@echo "$(BLUE)Waiting for NGINX Gateway to be ready...$(NC)"
	@$(KUBECTL) wait --for=condition=ready pod -l app.kubernetes.io/name=nginx-gateway -n nginx-gateway --timeout=180s
	@echo "$(GREEN)✓ NGINX Gateway Fabric installed$(NC)"

install-nginx-ingress: ## Install NGINX Ingress Controller
	@echo "$(BLUE)Installing NGINX Ingress Controller...$(NC)"
	@helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
	@helm repo update
	@helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
		--namespace ingress-nginx \
		--create-namespace \
		--set controller.service.type=LoadBalancer \
		--set controller.service.externalTrafficPolicy=Local \
		--set controller.config.use-forwarded-headers=true \
		--wait
	@echo "$(GREEN)✓ NGINX Ingress Controller installed$(NC)"

#═══════════════════════════════════════════════════════════════════════════════
# DEPLOYMENT
#═══════════════════════════════════════════════════════════════════════════════
deploy-infra-dev: check-secrets install-cert-manager install-nginx-ingress ## Deploy dev infrastructure
	@echo "$(BLUE)Step 1: Deploying operators (elastic, kafka, metallb)...$(NC)"
	@$(KUBECTL) apply -k infra/overlays/dev/storage/ || true
	@$(KUBECTL) apply -k infra/overlays/dev/elastic-operator/ || true
	@$(KUBECTL) apply -k infra/overlays/dev/kafka-operator/ || true
	@$(KUBECTL) apply -k infra/overlays/dev/metallb/ || true
	@echo "$(YELLOW)Waiting for operators to be ready...$(NC)"
	@sleep 10
	@$(KUBECTL) wait --for=condition=ready pod -n elastic-system --all --timeout=120s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=ready pod -n kafka --all --timeout=120s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=ready pod -n metallb-system --all --timeout=120s || true
	@echo "$(YELLOW)Waiting for MetalLB CRDs to be established...$(NC)"
	@$(KUBECTL) wait --for condition=established --timeout=60s crd/ipaddresspools.metallb.io 2>/dev/null || true
	@$(KUBECTL) wait --for condition=established --timeout=60s crd/l2advertisements.metallb.io 2>/dev/null || true
	@sleep 5
	@echo "$(BLUE)Step 2: Deploying cert-manager resources...$(NC)"
	@$(KUBECTL) apply -k infra/overlays/dev/cert-manager/ || true
	@sleep 5
	@echo "$(BLUE)Step 3: Deploying remaining infrastructure...$(NC)"
	@$(KUBECTL) apply -k infra/overlays/dev/
	@echo "$(GREEN)✓ Dev infrastructure deployed$(NC)"
	@echo "$(YELLOW)Waiting for key services to be ready...$(NC)"
	@$(KUBECTL) wait --for=condition=ready pod -l app=mongodb -n mongo --timeout=300s || true
	@echo "$(YELLOW)Checking certificates...$(NC)"
	@$(KUBECTL) get certificate -A 2>/dev/null || true

deploy-infra-dev-docker: check-secrets install-cert-manager install-nginx-ingress ## Deploy dev infrastructure
	@echo "$(BLUE)Step 1: Deploying operators (elastic, kafka, metallb)...$(NC)"
	@$(KUBECTL) apply -k infra/overlays/dev/elastic-operator/ || true
	@$(KUBECTL) apply -k infra/overlays/dev/kafka-operator/ || true
	@echo "$(YELLOW)Waiting for operators to be ready...$(NC)"
	@sleep 10
	@$(KUBECTL) wait --for=condition=ready pod -n elastic-system --all --timeout=120s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=ready pod -n kafka --all --timeout=120s 2>/dev/null || true
	@echo "$(BLUE)Step 2: Deploying cert-manager resources...$(NC)"
	@$(KUBECTL) apply -k infra/overlays/dev/cert-manager/ || true
	@sleep 5
	@echo "$(BLUE)Step 3: Deploying remaining infrastructure...$(NC)"
	@$(KUBECTL) apply -k infra/overlays/dev/
	@echo "$(GREEN)✓ Dev infrastructure deployed$(NC)"
	@echo "$(YELLOW)Waiting for key services to be ready...$(NC)"
	@$(KUBECTL) wait --for=condition=ready pod -l app=mongodb -n mongo --timeout=300s || true
	@echo "$(YELLOW)Checking certificates...$(NC)"
	@$(KUBECTL) get certificate -A 2>/dev/null || true

deploy-infra-stage: check-secrets install-cert-manager install-nginx-ingress ## Deploy stage infrastructure
	@echo "$(BLUE)Step 1: Deploying operators (elastic, kafka, metallb)...$(NC)"
	@$(KUBECTL) apply -k infra/overlays/stage/elastic-operator/ || true
	@$(KUBECTL) apply -k infra/overlays/stage/kafka-operator/ || true
	@$(KUBECTL) apply -k infra/overlays/stage/metallb/ || true
	@echo "$(YELLOW)Waiting for operators to be ready...$(NC)"
	@sleep 10
	@$(KUBECTL) wait --for=condition=ready pod -n elastic-system --all --timeout=120s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=ready pod -n kafka --all --timeout=120s 2>/dev/null || true
	@$(KUBECTL) wait --for=condition=ready pod -n metallb-system --all --timeout=120s || true
	@echo "$(YELLOW)Waiting for MetalLB CRDs to be established...$(NC)"
	@$(KUBECTL) wait --for condition=established --timeout=60s crd/ipaddresspools.metallb.io 2>/dev/null || true
	@$(KUBECTL) wait --for condition=established --timeout=60s crd/l2advertisements.metallb.io 2>/dev/null || true
	@echo "$(YELLOW)Waiting for MetalLB webhook to be ready...$(NC)"
	@$(KUBECTL) wait --for=condition=ready pod -l component=controller -n metallb-system --timeout=120s 2>/dev/null || true
	@sleep 5
	@echo "$(BLUE)Step 2: Deploying cert-manager resources...$(NC)"
	@$(KUBECTL) apply -k infra/overlays/stage/cert-manager/ || true
	@sleep 5
	@echo "$(BLUE)Step 3: Deploying remaining infrastructure...$(NC)"
	@$(KUBECTL) apply -k infra/overlays/stage/
	@echo "$(GREEN)✓ Stage infrastructure deployed$(NC)"
	@echo "$(YELLOW)Waiting for key services to be ready...$(NC)"
	@$(KUBECTL) wait --for=condition=ready pod -l app=mongodb -n mongo --timeout=300s || true
	@echo "$(YELLOW)Checking certificates...$(NC)"
	@$(KUBECTL) get certificate -A 2>/dev/null || true


deploy-infra-prod: check-secrets install-cert-manager install-nginx-ingress ## Deploy prod infrastructure
	@echo "$(BLUE)Deploying prod infrastructure...$(NC)"
	@read -p "Are you sure you want to deploy to PRODUCTION? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(BLUE)Step 1: Deploying operators (elastic, kafka, metallb)...$(NC)"; \
		$(KUBECTL) apply -k infra/overlays/prod/elastic-operator/ || true; \
		$(KUBECTL) apply -k infra/overlays/prod/kafka-operator/ || true; \
		$(KUBECTL) apply -k infra/overlays/prod/metallb/ || true; \
		echo "$(YELLOW)Waiting for operators to be ready...$(NC)"; \
		sleep 10; \
		$(KUBECTL) wait --for=condition=ready pod -n elastic-system --all --timeout=120s 2>/dev/null || true; \
		$(KUBECTL) wait --for=condition=ready pod -n kafka --all --timeout=120s 2>/dev/null || true; \
		$(KUBECTL) wait --for=condition=ready pod -n metallb-system --all --timeout=120s || true; \
		echo "$(YELLOW)Waiting for MetalLB CRDs to be established...$(NC)"; \
		$(KUBECTL) wait --for condition=established --timeout=60s crd/ipaddresspools.metallb.io 2>/dev/null || true; \
		$(KUBECTL) wait --for condition=established --timeout=60s crd/l2advertisements.metallb.io 2>/dev/null || true; \
		sleep 5; \
		echo "$(BLUE)Step 2: Deploying cert-manager resources...$(NC)"; \
		$(KUBECTL) apply -k infra/overlays/prod/cert-manager/ || true; \
		sleep 5; \
		echo "$(BLUE)Step 3: Deploying remaining infrastructure...$(NC)"; \
		$(KUBECTL) apply -k infra/overlays/prod/; \
		echo "$(YELLOW)Waiting for key services to be ready...$(NC)"; \
		$(KUBECTL) wait --for=condition=ready pod -l app=mongodb -n mongo --timeout=300s || true; \
		echo "$(GREEN)✓ Prod infrastructure deployed$(NC)"; \
	else \
		echo "$(YELLOW)Deployment cancelled$(NC)"; \
	fi

deploy-projects-dev: ## Deploy dev projects
	@echo "$(BLUE)Deploying dev projects...$(NC)"
	@$(KUBECTL) apply -k projects/overlays/dev/
	@echo "$(GREEN)✓ Dev projects deployed$(NC)"

deploy-projects-stage: ## Deploy stage projects
	@echo "$(BLUE)Deploying stage projects...$(NC)"
	@$(KUBECTL) apply -k projects/overlays/stage/
	@echo "$(GREEN)✓ Stage projects deployed$(NC)"

deploy-projects-prod: ## Deploy prod projects
	@echo "$(BLUE)Deploying prod projects...$(NC)"
	@read -p "Are you sure you want to deploy projects to PRODUCTION? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(KUBECTL) apply -k projects/overlays/prod/; \
		echo "$(GREEN)✓ Prod projects deployed$(NC)"; \
	else \
		echo "$(YELLOW)Deployment cancelled$(NC)"; \
	fi

deploy-dev: deploy-infra-dev deploy-projects-dev ## Deploy complete dev environment
	@echo "$(GREEN)✓ Complete dev environment deployed$(NC)"
	@echo "$(BLUE)Run 'make status' to check deployment status$(NC)"

deploy-stage: deploy-infra-stage deploy-projects-stage ## Deploy complete stage environment
	@echo "$(GREEN)✓ Complete stage environment deployed$(NC)"

deploy-prod: deploy-infra-prod deploy-projects-prod ## Deploy complete prod environment
	@echo "$(GREEN)✓ Complete prod environment deployed$(NC)"

#═══════════════════════════════════════════════════════════════════════════════
# STATUS & MONITORING
#═══════════════════════════════════════════════════════════════════════════════
status: ## Show status of all resources
	@echo "$(BLUE)=== Namespaces ===$(NC)"
	@$(KUBECTL) get ns | grep -v -E 'NAME|default|kube-' || true
	@echo ""
	@echo "$(BLUE)=== Pods Status ===$(NC)"
	@$(KUBECTL) get pods -A | grep -v -E 'NAMESPACE|^default |^kube-' || echo "No pods found"
	@echo ""
	@echo "$(BLUE)=== LoadBalancer Services & IPs ===$(NC)"
	@$(KUBECTL) get svc -A --field-selector spec.type=LoadBalancer -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORTS:.spec.ports[*].port' | grep -v 'NAMESPACE' || echo "No LoadBalancer services found"
	@echo ""
	@echo "$(BLUE)=== Ingresses ===$(NC)"
	@$(KUBECTL) get ingress -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTS:.spec.rules[*].host,ADDRESS:.status.loadBalancer.ingress[0].ip,PORTS:.spec.tls[*].secretName' | grep -v 'NAMESPACE' || echo "No ingresses found"
	@echo ""
	@echo "$(BLUE)=== Certificates ===$(NC)"
	@$(KUBECTL) get certificate -A || true

get-elk-pwd: ## Get the Elasticsearch elastic user password
	@echo "$(BLUE)Elasticsearch elastic user password:$(NC)"
	@$(KUBECTL) get secret elasticsearch-es-elastic-user -n elasticsearch -o jsonpath='{.data.elastic}' | base64 -d
	@echo ""

logs: ## Show logs for a namespace (usage: make logs NS=jenkins)
	@if [ -z "$(NS)" ]; then \
		echo "$(RED)Error: Namespace required. Usage: make logs NS=jenkins$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Logs for namespace: $(NS)$(NC)"
	@pods=$$($(KUBECTL) get pods -n $(NS) -o name 2>/dev/null); \
	if [ -z "$$pods" ]; then \
		echo "$(YELLOW)No pods found in namespace $(NS)$(NC)"; \
	else \
		for pod in $$pods; do \
			$(KUBECTL) logs -n $(NS) --all-containers --tail=50 $${pod##*/}; \
		done; \
	fi

restart-infra: ## Restart all infrastructure deployments and statefulsets
	@echo "$(BLUE)Restarting infrastructure workloads...$(NC)"
	@echo "$(YELLOW)⚠️  Warning: If Kafka fails with cluster ID mismatch, run 'make clean-kafka-data'$(NC)"
	@for ns in monitoring loki elasticsearch kafka mongo postgres minio mailhog sftp acme-nuxeo; do \
		echo "$(YELLOW)Restarting deployments in $$ns...$(NC)"; \
		$(KUBECTL) rollout restart deployment -n $$ns 2>/dev/null || echo "  No deployments in $$ns"; \
		echo "$(YELLOW)Restarting statefulsets in $$ns...$(NC)"; \
		$(KUBECTL) rollout restart statefulset -n $$ns 2>/dev/null || echo "  No statefulsets in $$ns"; \
	done
	@echo "$(GREEN)✓ All infrastructure workloads restarted$(NC)"
	@echo "$(BLUE)Run 'make status' to check restart progress$(NC)"

restart-namespace: ## Restart workloads in a specific namespace (usage: make restart-namespace NS=monitoring)
	@if [ -z "$(NS)" ]; then \
		echo "$(RED)Error: Namespace required. Usage: make restart-namespace NS=monitoring$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Restarting workloads in namespace: $(NS)$(NC)"
	@echo "$(YELLOW)Restarting deployments...$(NC)"
	@$(KUBECTL) rollout restart deployment -n $(NS) 2>/dev/null || echo "  No deployments found"
	@echo "$(YELLOW)Restarting statefulsets...$(NC)"
	@$(KUBECTL) rollout restart statefulset -n $(NS) 2>/dev/null || echo "  No statefulsets found"
	@echo "$(GREEN)✓ Workloads in $(NS) restarted$(NC)"

#═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
#═══════════════════════════════════════════════════════════════════════════════
delete-dev: ## Delete dev environment
	@echo "$(YELLOW)Deleting dev environment...$(NC)"
	@$(KUBECTL) delete -k projects/overlays/dev/ --ignore-not-found=true
	@$(KUBECTL) delete -k infra/overlays/dev/ --ignore-not-found=true
	@echo "$(GREEN)✓ Dev environment deleted$(NC)"

delete-projects-dev: ## Delete only dev projects (keep infrastructure)
	@echo "$(YELLOW)Deleting dev projects...$(NC)"
	@$(KUBECTL) delete -k projects/overlays/dev/ --ignore-not-found=true
	@echo "$(GREEN)✓ Dev projects deleted$(NC)"

delete-stage: ## Delete stage environment
	@echo "$(YELLOW)Deleting stage environment...$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(KUBECTL) delete -k projects/overlays/stage/ --ignore-not-found=true; \
		$(KUBECTL) delete -k infra/overlays/stage/ --ignore-not-found=true; \
		echo "$(GREEN)✓ Stage environment deleted$(NC)"; \
	fi

delete-projects-stage: ## Delete only stage projects (keep infrastructure)
	@echo "$(YELLOW)Deleting stage projects...$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(KUBECTL) delete -k projects/overlays/stage/ --ignore-not-found=true; \
		echo "$(GREEN)✓ Stage projects deleted$(NC)"; \
	fi

delete-infra-stage: ## Delete only stage infrastructure (keep projects)
	@echo "$(YELLOW)Deleting stage infrastructure...$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(YELLOW)Starting deletion (will not wait for graceful termination)...$(NC)"; \
		$(KUBECTL) delete -k infra/overlays/stage/ --ignore-not-found=true --grace-period=0 --force --timeout=10s 2>&1 | head -n 20 & \
		echo "$(YELLOW)Waiting 3 seconds for deletion to start...$(NC)"; \
		sleep 3; \
		echo "$(YELLOW)Force deleting pods in infrastructure namespaces...$(NC)"; \
		for ns in elasticsearch gitlab kafka keycloak loki mailhog minio mongo monitoring postgres redis sftp jenkins cert-manager elastic-system local-path-storage metallb-system; do \
			$(KUBECTL) delete pods --all -n $$ns --grace-period=0 --force 2>/dev/null || true; \
		done; \
		echo "$(YELLOW)Removing namespace finalizers...$(NC)"; \
		for ns in elasticsearch gitlab kafka keycloak loki mailhog minio mongo monitoring postgres redis sftp jenkins cert-manager elastic-system ingress-nginx local-path-storage metallb-system; do \
			$(KUBECTL) get namespace $$ns -o json 2>/dev/null | jq '.spec.finalizers = []' | $(KUBECTL) replace --raw /api/v1/namespaces/$$ns/finalize -f - 2>/dev/null || true; \
		done; \
		echo "$(YELLOW)Deleting cert-manager...$(NC)"; \
		$(KUBECTL) delete namespace cert-manager --ignore-not-found=true --grace-period=0 2>/dev/null || true; \
		echo "$(YELLOW)Deleting NGINX Ingress Controller...$(NC)"; \
		helm uninstall nginx-ingress -n ingress-nginx 2>/dev/null || true; \
		$(KUBECTL) delete namespace ingress-nginx --ignore-not-found=true --grace-period=0 2>/dev/null || true; \
		echo "$(YELLOW)Waiting for cleanup to complete...$(NC)"; \
		sleep 5; \
		echo "$(GREEN)✓ Stage infrastructure deleted$(NC)"; \
		echo "$(BLUE)Remaining namespaces:$(NC)"; \
		$(KUBECTL) get ns | grep -v -E 'NAME|default|kube-' || echo "  All infrastructure namespaces removed"; \
	fi

delete-prod: ## Delete prod environment
	@echo "$(RED)WARNING: You are about to delete the PRODUCTION environment!$(NC)"
	@read -p "Type 'delete-production' to confirm: " confirm; \
	if [ "$$confirm" = "delete-production" ]; then \
		$(KUBECTL) delete -k projects/overlays/prod/ --ignore-not-found=true; \
		$(KUBECTL) delete -k infra/overlays/prod/ --ignore-not-found=true; \
		echo "$(GREEN)✓ Prod environment deleted$(NC)"; \
	else \
		echo "$(YELLOW)Deletion cancelled$(NC)"; \
	fi

delete-projects-prod: ## Delete only prod projects (keep infrastructure)
	@echo "$(RED)WARNING: You are about to delete PRODUCTION projects!$(NC)"
	@read -p "Type 'delete-production-projects' to confirm: " confirm; \
	if [ "$$confirm" = "delete-production-projects" ]; then \
		$(KUBECTL) delete -k projects/overlays/prod/ --ignore-not-found=true; \
		echo "$(GREEN)✓ Prod projects deleted$(NC)"; \
	else \
		echo "$(YELLOW)Deletion cancelled$(NC)"; \
	fi

clean-all: ## Delete everything including PVCs (WARNING: DATA LOSS!)
	@echo "$(RED)WARNING: This will delete ALL environments and ALL data!$(NC)"
	@read -p "Type 'delete-everything' to confirm: " confirm; \
	if [ "$$confirm" = "delete-everything" ]; then \
		$(KUBECTL) delete -k projects/overlays/dev/ --ignore-not-found=true; \
		$(KUBECTL) delete -k projects/overlays/stage/ --ignore-not-found=true; \
		$(KUBECTL) delete -k projects/overlays/prod/ --ignore-not-found=true; \
		$(KUBECTL) delete -k infra/overlays/dev/ --ignore-not-found=true; \
		$(KUBECTL) delete -k infra/overlays/stage/ --ignore-not-found=true; \
		$(KUBECTL) delete -k infra/overlays/prod/ --ignore-not-found=true; \
		echo "$(YELLOW)Deleting all PVCs...$(NC)"; \
		$(KUBECTL) delete pvc -A --all --ignore-not-found=true; \
		echo "$(GREEN)✓ Everything deleted$(NC)"; \
	else \
		echo "$(YELLOW)Deletion cancelled$(NC)"; \
	fi

#═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
#═══════════════════════════════════════════════════════════════════════════════
check-ingress: ## Check NGINX Ingress status
	@echo "$(BLUE)Checking NGINX Ingress Controller...$(NC)"
	@$(KUBECTL) get pods -n ingress-nginx
	@$(KUBECTL) get ingress -n default
	@$(KUBECTL) get ingressclass

check-certs: ## Check certificate status
	@echo "$(BLUE)Checking certificates...$(NC)"
	@$(KUBECTL) get certificate -A
	@$(KUBECTL) get clusterissuer

check-routes: ## Check HTTPRoute status
	@echo "$(BLUE)Checking HTTPRoutes...$(NC)"
	@$(KUBECTL) get httproute -A

check-monitoring: ## Check monitoring stack status
	@echo "$(BLUE)Checking Monitoring Stack...$(NC)"
	@echo ""
	@echo "$(BLUE)=== Prometheus ===$(NC)"
	@$(KUBECTL) get pods -n monitoring -l app=prometheus
	@echo ""
	@echo "$(BLUE)=== Grafana ===$(NC)"
	@$(KUBECTL) get pods -n monitoring -l app=grafana
	@echo ""
	@echo "$(BLUE)=== Storage ===$(NC)"
	@$(KUBECTL) get pvc -n monitoring
	@echo ""

shell-mongo: ## Open shell in MongoDB pod
	@$(KUBECTL) exec -it -n mongo $$($(KUBECTL) get pod -n mongo -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -- mongosh

shell-postgres: ## Open shell in PostgreSQL pod
	@$(KUBECTL) exec -it -n postgres $$($(KUBECTL) get pod -n postgres -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- psql -U postgres

shell-jenkins: ## Open shell in Jenkins pod
	@$(KUBECTL) exec -it -n jenkins $$($(KUBECTL) get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- /bin/bash

drain-node: ## Drain node for maintenance (usage: make drain-node NODE=k8s-worker2)
	@if [ -z "$(NODE)" ]; then \
		echo "$(RED)Error: NODE variable required. Usage: make drain-node NODE=k8s-worker2$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Cordoning node $(NODE)...$(NC)"
	@kubectl cordon $(NODE)
	@echo "$(YELLOW)Draining node $(NODE)...$(NC)"
	@kubectl drain $(NODE) --ignore-daemonsets --delete-emptydir-data
	@echo "$(GREEN)✓ Node $(NODE) drained and cordoned$(NC)"

uncordon-node: ## Re-enable scheduling on node (usage: make uncordon-node NODE=k8s-worker2)
	@if [ -z "$(NODE)" ]; then \
		echo "$(RED)Error: NODE variable required. Usage: make uncordon-node NODE=k8s-worker2$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Uncordoning node $(NODE)...$(NC)"
	@kubectl uncordon $(NODE)
	@echo "$(GREEN)✓ Node $(NODE) is schedulable again$(NC)"

copy-k8s-kubeconfig: ## Export kubeconfig for specific context
	@if [ -z "$(CONTEXT)" ]; then \
		echo "$(RED)Error: CONTEXT variable required. Usage: make copy-k8s-kubeconfig CONTEXT=my-context$(NC)"; \
		exit 1; \
	fi
	@kubectl config view --raw --minify --context=$(CONTEXT) > $(CONTEXT).yaml
	@echo "$(GREEN)✓ Kubeconfig copied to $(CONTEXT).yaml$(NC)"

load-k8s-kubeconfig: ## Display instructions to load kubeconfig
	@echo "$(BLUE)To load the kubeconfig, run this command in your shell:$(NC)"
	@echo "$(YELLOW)export KUBECONFIG=~/.kube/config:~/kubeconfig-k8s.yaml$(NC)"
	@echo "$(BLUE)Or add it to your ~/.zshrc or ~/.bashrc for persistence.$(NC)"

redeploy-acme-nuxeo23: ## Redeploy ACME Nuxeo (internal use)
	@$(KUBECTL) delete deployment nuxeo-api-deployment -n acme-nuxeo23 && \
	$(KUBECTL) delete pod -l app=nuxeo-api-deployment -n acme-nuxeo23 && \
	$(KUBECTL) apply -k projects/overlays/prod/acme-nuxeo23/

redeploy-acme-nuxeo25: ## Redeploy ACME Nuxeo (internal use)
	@$(KUBECTL) delete deployment nuxeo-api-deployment -n acme-nuxeo25 && \
	$(KUBECTL) delete pod -l app=nuxeo-api-deployment -n acme-nuxeo25 && \
	$(KUBECTL) apply -k projects/overlays/prod/acme-nuxeo25/