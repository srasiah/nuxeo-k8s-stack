# Nuxeo Kubernetes Stack

A Kubernetes infrastructure stack for deploying Nuxeo and supporting services across multiple environments.

## 🚀 Quick Start

```bash
# 1. Install prerequisites
make install-tools

# 2. Create secrets
make create-secrets

# 3. Check environment configuration (optional)
make check-env-dev

# 4. Deploy infrastructure
make deploy-infra-dev-docker

# 5. Check status
make status
```

> **💡 Tip:** Run `make help` to see all available commands

## 📋 Table of Contents

- [Environments](#environments)
- [Infrastructure Components](#infrastructure-components)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Project Structure](#project-structure)
- [Common Tasks](#common-tasks)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Security](#security)

---

## Environments

Three environments are supported with automatic DNS and TLS configuration:

| Environment | Domain | Certificate | Use Case |
|------------|---------|------------|----------|
| **Dev** | *.dev.local.dev | Self-signed | Local development |
| **Stage** | *.lab.sample.dev | Let's Encrypt Staging | Pre-production testing |
| **Prod** | *.k8s.example.dev | Let's Encrypt Production | Production workloads |

### Service URLs

All services follow the pattern: `https://<service>.<environment-domain>`

**Example:**
- Kafka UI: https://kafka-ui.k8s.local.dev
- Kibana: https://kibana.k8s.local.dev
- MinIO: https://minio.k8s.local.dev
- Grafana: https://grafana.k8s.local.dev

---

## Infrastructure Components

### Core Services
- **Nuxeo** - Content management platform
- **PostgreSQL** - Primary relational database (with pgAdmin)
- **MongoDB** - Document database (with Mongo Express)
- **Elasticsearch** - Search and analytics (with Kibana)
- **Redis** - Caching and session storage

### Messaging & Streaming
- **Kafka** - Event streaming platform (with Strimzi operator and Kafka UI)

### Storage & Files
- **MinIO** - S3-compatible object storage
- **SFTP** - Secure file transfer

### DevOps Tools
- **GitLab** - Source control and CI/CD
- **Jenkins** - Automation server

### Monitoring & Observability
- **Grafana** - Metrics visualization
- **Prometheus** - Metrics collection
- **Loki** - Log aggregation
- **Kibana** - Log visualization

### Supporting Services
- **MailHog** - Email testing
- **Keycloak** - Identity and access management

### Infrastructure
- **cert-manager** - Automated TLS certificate management
- **NGINX Ingress** - HTTP/HTTPS routing and load balancing
- **MetalLB** - Load balancer for bare-metal Kubernetes

---

## Project Structure

```
├── infra/
│   ├── base/                    # Base Kubernetes manifests
│   │   ├── cert-manager/        # TLS certificate management
│   │   ├── elasticsearch/       # Search engine + Kibana
│   │   ├── kafka/              # Event streaming + Kafka UI + Zookeeper
│   │   ├── mongo/              # MongoDB + Mongo Express
│   │   ├── postgres/           # PostgreSQL + pgAdmin
│   │   ├── minio/              # Object storage
│   │   ├── jenkins/            # CI/CD automation server
│   │   ├── mailhog/            # Email testing
│   │   └── sftp/               # File transfer
│   └── overlays/
│       ├── dev/                # Development environment (*.dev.vjsha.dev)
│       ├── stage/              # Staging environment (*.lab.vjsha.dev)
│       └── prod/               # Production environment (*.prod.vjsha.dev)
│       └── prod/               # Production environment (example.com)
projects/
	base/
		nuxeo/
	overlays/
		01-acme-nuxeo/          # Dev Nuxeo project
		stage/
			acme-nuxeo/         # Stage Nuxeo project
		prod/
			acme-nuxeo/         # Prod Nuxeo project
├── projects/
│   ├── base/                   # Base application manifests
│   │   └── nuxeo/             # Nuxeo application
│   └── overlays/              # Application overlays
└── helm-values/               # Helm chart values
    ├── grafana/
    └── prometheus-grafana/

```

## Prerequisites

### Required
- **Kubernetes cluster** (v1.24+)
  - Local: Docker Desktop, minikube, kind
  - Cloud: AKS, EKS, GKE
  - On-premise: kubeadm, k3s, RKE2
- **kubectl** CLI (v1.24+)
- **make** utility

### Recommended
- **Helm** (v3.0+) for monitoring stack
- 32GB+ RAM for full stack
- 100GB+ storage for persistent volumes

### Cluster Requirements
- **Nodes**: Minimum 2 worker nodes recommended
- **Storage**: Dynamic volume provisioning
- **Network**: LoadBalancer support (MetalLB for bare-metal)

### Quick Setup
```bash
# Install kubectl (macOS)
brew install kubectl

# Verify cluster access
kubectl cluster-info

# Run prerequisites check
make install-tools
```

---

## Installation

### 1. Clone Repository
```bash
git clone <repository-url>
cd nuxeo-k8s-stack
```

### 2. Create Secrets
```bash
# Generate secret files from templates
make create-secrets

# Edit secrets with your credentials
nano secrets/.env.postgres.secret
nano secrets/.env.mongo.secret
# ... edit other secret files as needed

# Verify all required secret files exist
make check-secrets
```

### 3. Configure Environment Variables
```bash
# Create and configure overlay-specific environment files
# Each overlay (dev/stage/prod) requires its own .env files

# Check which environment files are required and missing
make check-env-dev      # Check dev overlay env files
make check-env-stage    # Check stage overlay env files
make check-env-all      # Check all environments at once

# Environment files are located in:
# - infra/overlays/{dev,stage,prod}/*/.env.*
# - projects/overlays/{dev,stage,prod}/*/.env.*
```

> **📌 Note:** Environment files (.env.*) contain deployment-specific configuration like domain names, resource limits, and service endpoints. These are separate from secret files (.env.*.secret) which contain sensitive credentials.

### 4. Validate Configuration
```bash
# Validate specific environment
make validate-dev

# Or validate all environments
make validate-all
```

### 5. Deploy Infrastructure
```bash
# Deploy to dev docker
make deploy-infra-dev-docker

# The Makefile will:
# - Install NGINX Ingress Controller
# - Deploy all infrastructure components
# - Wait for services to be ready
# - Display deployment status
```

### 6. Deploy Applications (Optional)
```bash
# Deploy Nuxeo applications
make get-elk-pwd
make deploy-projects-dev
```

### 7. Verify Deployment
```bash
# Check overall status
make status

# Check specific service
kubectl get pods -n gitlab
kubectl get pods -n kafka
```

---
```
https://pgadmin.k8s.local.dev
https://mongo-express.k8s.local.dev
(and other services...)
```

## Common Tasks

### Deploy Single Component
```bash
# Deploy only kafka infrastructure
kubectl apply -k infra/overlays/dev/kafka

# Deploy specific application
kubectl apply -k projects/overlays/dev/acme-nuxeo25
```

### Update Configuration
```bash
# After modifying kustomization files
make deploy-infra-dev-docker

# Or specific overlay
kubectl apply -k infra/overlays/dev
```

### Verify Environment Configuration
```bash
# Check all required secret files (for base infrastructure)
make check-secrets

# Check overlay environment files
make check-env-dev       # Verify dev environment files
make check-env-stage     # Verify stage environment files  
make check-env-prod      # Verify prod environment files
make check-env-all       # Verify all environments

# Validate kustomization syntax
make validate-dev      # Validate stage overlay
make validate-all        # Validate all overlays
```

### Check Component Status
```bash
# All infrastructure components
make status

# Specific namespace
kubectl get pods -n kafka
kubectl get pods -n gitlab
kubectl get pods -n postgres

# View logs
kubectl logs -n kafka kafka-cluster-kafka-0
kubectl logs -n gitlab deployment/gitlab -f
```

### Scale Applications
```bash
# Scale Kafka cluster
kubectl edit kafkanodepool kafka-pool -n kafka

# Scale Nuxeo instances
kubectl scale deployment nuxeo --replicas=3 -n nuxeo
```

### Certificate Management Stage
```bash
# Check certificate status
kubectl get certificates -A
kubectl describe certificate selfsigned-issuer -n cert-manager

# Force certificate renewal
kubectl delete certificate selfsigned-issuer -n cert-manager
make dstaged
```

### Access Services

#### Dev Local (k8s.local.dev)
```
https://kafka-ui.k8s.local.dev
# ... (same pattern for all services)
```

#### Port Forwarding (Alternative Access)
```bash
# Use make command to see all port-forward options
make port-forward

# Manual port forward examples
kubectl port-forward -n gitlab svc/gitlab 8080:80
kubectl port-forward -n kafka svc/kafka-ui 8090:8080
```

---

## Monitoring

### Deploy Monitoring Stack

```bash
# Deploys Prometheus, Grafana, and Loki
make deploy-infra-dev-docker
```

### Access Monitoring Tools

#### Grafana Dashboards
- **Dev Local**: https://grafana.k8s.local.dev
- **Stage**: https://grafana.stage.example.dev

Default credentials:
- Username: `admin`
- Password: Check `secrets/.env.grafana.secret`


#### Loki Logs
Integrated with Grafana. Access through Grafana's Explore view.

### Pre-configured Dashboards

The stack includes dashboards for:
- Kubernetes cluster metrics
- Kafka metrics (Strimzi operator)
- Elasticsearch/Kibana metrics
- PostgreSQL metrics
- MongoDB metrics
- Application metrics (Nuxeo)

### Adding Custom Dashboards

1. Create dashboard in Grafana UI
2. Export JSON from Grafana
3. Save to `infra/base/monitoring/dashboards/`
4. Add to ConfigMap in `infra/base/monitoring/grafana-dashboards-configmap.yaml`
5. Redeploy: `make deploy-infra-dev-docker`

---

## Troubleshooting

### Common Issues

#### Pods Stuck in Pending
```bash
# Check PVC status
kubectl get pvc -A

# Check node resources
kubectl describe node

# Check events
kubectl get events -A --sort-by='.lastTimestamp'
```

**Solutions:**
- Ensure StorageClass is available: `kubectl get storageclass`
- Check node capacity: `kubectl top nodes`
- Review pod events: `kubectl describe pod <pod-name> -n <namespace>`

#### Services Not Accessible (502/503 Errors)
```bash
# Verify NGINX Gateway
kubectl get pods -n nginx-ingress
kubectl logs -n nginx-ingress deployment/ingress-nginx-controller

# Check certificates
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>

# Verify Ingress rules
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>
```

**Solutions:**
- Check Ingress `backend` service name and port match Service spec
- Verify certificate is Ready: `kubectl get certificate -A`
- Check DNS resolution: `nslookup <domain>`
- Restart NGINX: `kubectl rollout restart deployment -n nginx-ingress`

#### Database Connection Failures
```bash
# Check PostgreSQL
kubectl get pods -n postgres
kubectl logs -n postgres postgres-0

# Check MongoDB
kubectl get pods -n mongodb
kubectl logs -n mongodb mongodb-0

# Test database connectivity
kubectl run -it --rm debug --image=postgres:16 --restart=Never -- psql -h postgres-service.postgres.svc.cluster.local -U postgres
```

**Solutions:**
- Verify database pods are running
- Check secrets are created: `kubectl get secrets -n <namespace>`
- Verify service DNS: `kubectl get svc -n postgres`
- Check database logs for initialization errors

#### Kafka Issues
```bash
# Check Strimzi operator
kubectl get pods -n kafka-operator

# Check Kafka cluster
kubectl get kafka -n kafka
kubectl describe kafka kafka-cluster -n kafka

# Check node pools
kubectl get kafkanodepool -n kafka
```

**Solutions:**
- Ensure Strimzi operator is running
- Check Kafka custom resources are valid
- Review Kafka pod logs: `kubectl logs -n kafka kafka-cluster-kafka-0`
- For node-specific issues, check node affinity/taints

#### Certificate Not Issuing
```bash
# Check cert-manager
kubectl get pods -n cert-manager
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate requests
kubectl get certificaterequest -A
kubectl describe certificaterequest <request-name> -n <namespace>

# Check challenges (for Let's Encrypt)
kubectl get challenges -A
```

**Solutions:**
- Verify cert-manager is running
- Check ClusterIssuer is ready: `kubectl get clusterissuer`
- For Let's Encrypt, verify DNS is publicly accessible
- Review cert-manager logs for ACME challenge errors

#### Node-Specific Issues (Corrupted Storage)
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check node taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# View pod distribution
kubectl get pods -A -o wide
```

**Solutions:**
- Taint problematic nodes: `kubectl taint node <node> corrupted-storage=true:NoSchedule`
- Use node affinity to force scheduling to healthy nodes
- Rebuild node or repair containerd storage
- Check containerd status: `systemctl status containerd`

#### Secret-Related Errors
```bash
# Verify secrets exist
kubectl get secrets -A | grep <secret-name>

# Check secret creation
make check-secrets

# Recreate secrets
make create-secrets
```

**Solutions:**
- Run `make create-secrets` to generate template files
- Edit secret files in `secrets/` directory with actual credentials
- Verify secret encoding: `kubectl get secret <name> -o yaml -n <namespace>`
- Redeploy to apply updated secrets: `make deploy-infra-prod`

---

## Security Considerations

### Secrets Management

- All sensitive credentials stored in `secrets/` directory (gitignored)
- Use `make create-secrets` to generate template files
- Never commit actual credentials to version control
- Rotate credentials regularly

### Network Security

- All services use HTTPS with valid TLS certificates
- cert-manager automates certificate lifecycle
- Production uses Let's Encrypt production certificates
- Stage uses Let's Encrypt staging (for testing)

### Access Control

- PostgreSQL requires authentication (credentials in secrets)
- MongoDB requires authentication (credentials in secrets)
- Redis requires authentication where applicable
- Kafka uses SASL/SCRAM authentication (optional)
- Keycloak provides centralized authentication/authorization

### Best Practices

- Use non-root containers where possible
- Apply resource limits to prevent resource exhaustion
- Enable Pod Security Standards (restricted/baseline)
- Regularly update container images for security patches
- Use NetworkPolicies to restrict pod-to-pod communication
- Enable audit logging for compliance requirements

### Compliance

- All database connections encrypted in transit
- Persistent data encrypted at rest (if supported by StorageClass)
- Regular backups of critical data (PostgreSQL, MongoDB, MinIO)
- Monitoring and alerting for security events

---

## Additional Resources

### Component Documentation

- [cert-manager](infra/base/cert-manager/) - TLS certificate management
- [Jenkins](infra/base/jenkins/) - CI/CD configuration
- [Kafka](infra/base/kafka/) - Messaging platform setup
- [Elasticsearch](infra/base/elasticsearch/) - Search and analytics

### Useful Commands

```bash
# View all resources across namespaces
kubectl get all -A

# Check cluster events
kubectl get events -A --sort-by='.lastTimestamp'

# View resource usage
kubectl top nodes
kubectl top pods -A

# Debug pod startup issues
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous

# Port forward for local access
make port-forward  # Shows all available port-forward commands
```

### Reference Documentation

#### Core Platform
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Guide](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)

#### Application & Content Management
- [Nuxeo Documentation](https://doc.nuxeo.com/)
- [Nuxeo Platform](https://www.nuxeo.com/products/platform/)

#### Databases
- [PostgreSQL](https://www.postgresql.org/docs/)
- [pgAdmin](https://www.pgadmin.org/docs/)
- [MongoDB](https://www.mongodb.com/docs/)
- [Mongo Express](https://github.com/mongo-express/mongo-express)
- [Redis](https://redis.io/docs/)

#### Search & Analytics
- [Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Kibana](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Elastic Operator (ECK)](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html)

#### Messaging & Streaming
- [Apache Kafka](https://kafka.apache.org/documentation/)
- [Strimzi Kafka Operator](https://strimzi.io/docs/operators/latest/overview)
- [Kafka UI](https://github.com/provectus/kafka-ui)

#### Storage
- [MinIO](https://min.io/docs/minio/kubernetes/upstream/index.html)
- [MinIO Console](https://min.io/docs/minio/linux/administration/minio-console.html)

#### DevOps & CI/CD
- [GitLab](https://docs.gitlab.com/)
- [GitLab on Kubernetes](https://docs.gitlab.com/charts/)
- [Jenkins](https://www.jenkins.io/doc/)
- [Jenkins on Kubernetes](https://www.jenkins.io/doc/book/installing/kubernetes/)

#### Monitoring & Observability
- [Prometheus](https://prometheus.io/docs/)
- [Grafana](https://grafana.com/docs/grafana/latest/)
- [Loki](https://grafana.com/docs/loki/latest/)
- [Promtail](https://grafana.com/docs/loki/latest/clients/promtail/)
- [Kube State Metrics](https://github.com/kubernetes/kube-state-metrics)
- [Node Exporter](https://github.com/prometheus/node_exporter)

#### Identity & Access Management
- [Keycloak](https://www.keycloak.org/documentation/)
- [Keycloak on Kubernetes](https://www.keycloak.org/operator/installation)

#### Networking & Ingress
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [NGINX Ingress Annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)
- [MetalLB](https://metallb.universe.tf/)

#### TLS & Certificates
- [cert-manager](https://cert-manager.io/docs/)
- [Let's Encrypt](https://letsencrypt.org/docs/)

#### Development & Testing
- [MailHog](https://github.com/mailhog/MailHog)
- [SFTP Server](https://github.com/atmoz/sftp)

---

## License

See [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly in dev environment
5. Validate changes: `make validate-dev`
6. Submit a pull request

---

**Project Status**: POC with active deployments on k8s.example.dev (prod) and lab.sample.dev (stage).


