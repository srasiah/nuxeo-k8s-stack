# Jenkins CI/CD Server

This directory contains Kubernetes manifests for deploying Jenkins with Kubernetes integration.

## Components

- **Jenkins**: Automation server for CI/CD pipelines (v2.545-jdk21)
- **ServiceAccount & RBAC**: Kubernetes integration for dynamic agent provisioning

## Resources Included

### Base Resources
1. **Namespace**: `jenkins` namespace for all Jenkins resources
2. **PVC**: 10Gi persistent volume claim for Jenkins home directory
3. **ServiceAccount**: `jenkins` service account with cluster permissions
4. **ClusterRole & ClusterRoleBinding**: RBAC for pod management
5. **Deployment**: Jenkins controller/master
6. **Service**: ClusterIP service exposing Jenkins UI (8080) and agent port (50000)

## Configuration

### Storage

- **Jenkins Home**: 10Gi persistent storage mounted at `/var/jenkins_home`
- Stores all Jenkins configuration, jobs, plugins, and build history

### Resource Limits

**Jenkins**:
- CPU: 500m (request) / 2 cores (limit)
- Memory: 1Gi (request) / 2Gi (limit)

### Security Context

Runs as user/group `1000` (jenkins user) with appropriate filesystem permissions.

## Health Checks

Jenkins includes:
- **Liveness Probe**: HTTP check on `/login` every 10s after 90s
- **Readiness Probe**: HTTP check on `/login` every 10s after 60s

## Access

### Web UI

Access Jenkins through:
- **Dev overlay**: http://jenkins.docker.local (via Ingress)
- **Port-forward**: `kubectl port-forward -n jenkins svc/jenkins-service 8080:8080`

### Security Setup

**Important**: Jenkins 2.545 deploys with security disabled by default for initial setup.

To enable authentication:

1. Access Jenkins at https://jenkins.k8s.local (or your configured hostname)
2. Go to **Manage Jenkins** → **Security**
3. Under **Security Realm**, select "Jenkins' own user database"
4. Check "Allow users to sign up" (temporarily)
5. Under **Authorization**, select "Logged-in users can do anything" or "Matrix-based security"
6. Click **Save**
7. Sign up to create your admin account
8. Go back to Security settings and uncheck "Allow users to sign up"

**Configuration as Code**: The deployment includes JCasC configuration for automated security setup, but requires the `configuration-as-code` plugin to be successfully installed first.

Note: Setup wizard is disabled by default (`-Djenkins.install.runSetupWizard=false`).

## Kubernetes Integration

### Plugin Installation

Jenkins plugins are automatically installed via init container using `:latest` versions. To add/remove plugins:

1. Edit `30-jenkins-plugins-configmap.yaml`
2. Add plugin in format: `plugin-name:latest` or `plugin-name:specific-version`
3. Find plugin versions at: https://plugins.jenkins.io/
4. Redeploy: `kubectl delete pod -n jenkins -l app=jenkins`

**⚠️ Important**: Due to Jenkins update server availability issues (502/503 errors from updates.jenkins.io and mirror sites), automatic plugin installation via the init container may fail. **Plugins must be installed manually through the Jenkins UI**.

**Manual Plugin Installation Steps**:
1. Access Jenkins at https://jenkins.k8s.local
2. Go to **Manage Jenkins** → **Plugins** → **Available Plugins**
3. Search and install these essential plugins:
   - Kubernetes (for dynamic agent provisioning)
   - Pipeline (workflow-aggregator)
   - Git
   - Configuration as Code (for JCasC)
   - Docker Pipeline
   - Kubernetes CLI
4. Restart Jenkins after installation: **Manage Jenkins** → **Reload Configuration from Disk**

The init container will retry plugin installation on each pod restart, but until update servers are stable, manual installation is the most reliable approach.

**Configured Plugins** (installed as `:latest`):
- kubernetes - Dynamic Kubernetes agent provisioning
- workflow-aggregator - Pipeline plugin suite
- git - Git SCM integration
- configuration-as-code - JCasC for automated configuration
- credentials-binding - Credential management in pipelines
- job-dsl - Job DSL for pipeline creation
- docker-workflow - Docker pipeline integration
- pipeline-stage-view - Pipeline stage visualization
- blueocean - Modern UI
- kubernetes-cli - kubectl commands in pipelines
- gitlab-plugin - GitLab integration

### Configuration as Code (JCasC)

Jenkins is configured automatically using JCasC. Configuration is in `31-jenkins-casc-configmap.yaml`.

To modify:
1. Edit the ConfigMap
2. Reload: `kubectl rollout restart deployment/jenkins -n jenkins`
3. Or reload via UI: **Manage Jenkins** → **Configuration as Code** → **Reload existing configuration**

### RBAC Permissions

The Jenkins ServiceAccount has permissions to:
- Create, delete, get, list, patch, update, and watch pods
- Execute commands in pods and view logs
- Read secrets

### Dynamic Agent Provisioning

Jenkins can provision Kubernetes pods as build agents. Install the Kubernetes plugin and configure:

1. Go to **Manage Jenkins** → **Configure System**
2. Add a cloud: **Kubernetes**
3. Set Kubernetes URL: `https://kubernetes.default.svc.cluster.local`
4. Set namespace: `jenkins`
5. Jenkins URL: `http://jenkins-service.jenkins.svc.cluster.local:8080`

## Deployment

Deploy using kustomize:

```bash
# Deploy base
kubectl apply -k infra/base/jenkins/

# Deploy with dev overlay
kubectl apply -k infra/overlays/dev/jenkins/
```

## Verify Deployment

```bash
# Check all resources
kubectl get all -n jenkins

# Check Jenkins logs
kubectl logs -n jenkins deployment/jenkins

# Check ServiceAccount
kubectl get sa -n jenkins
kubectl describe clusterrolebinding jenkins
```

## Plugin Installation

### Recommended Plugins

1. **Kubernetes Plugin**: For dynamic agent provisioning
2. **Git Plugin**: For Git repository integration
3. **Pipeline Plugin**: For Jenkins pipelines
4. **Docker Plugin**: For Docker integration
5. **Blue Ocean**: Modern UI

### Install via Jenkins UI

Navigate to **Manage Jenkins** → **Plugin Manager** → **Available Plugins**

### Install via CLI

```bash
kubectl exec -n jenkins deployment/jenkins -- jenkins-plugin-cli --plugins kubernetes:latest git:latest workflow-aggregator:latest blueocean:latest
```

## Configuration as Code (JCasC)

For automated configuration, mount a ConfigMap with JCasC YAML:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: jenkins-config
  namespace: jenkins
data:
  jenkins.yaml: |
    jenkins:
      systemMessage: "Jenkins on Kubernetes"
      numExecutors: 0
      clouds:
        - kubernetes:
            name: "kubernetes"
            serverUrl: "https://kubernetes.default"
            namespace: "jenkins"
            jenkinsUrl: "http://jenkins-service:8080"
```

Then mount it in the deployment and set `CASC_JENKINS_CONFIG` environment variable.

## Pipeline Example

### Kubernetes Pod Template

```groovy
podTemplate(
  cloud: 'kubernetes',
  namespace: 'jenkins',
  containers: [
    containerTemplate(
      name: 'maven',
      image: 'maven:3.9-eclipse-temurin-21',
      command: 'sleep',
      args: 'infinity'
    )
  ]
) {
  node(POD_LABEL) {
    stage('Build') {
      container('maven') {
        sh 'mvn clean package'
      }
    }
  }
}
```

## Backup and Restore

### Backup Jenkins Home

```bash
# Create a backup
kubectl exec -n jenkins deployment/jenkins -- tar czf /tmp/jenkins-backup.tar.gz -C /var/jenkins_home .
kubectl cp jenkins/$(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}'):/tmp/jenkins-backup.tar.gz ./jenkins-backup.tar.gz
```

### Restore Jenkins Home

```bash
# Copy backup to pod
kubectl cp ./jenkins-backup.tar.gz jenkins/$(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}'):/tmp/

# Restore
kubectl exec -n jenkins deployment/jenkins -- tar xzf /tmp/jenkins-backup.tar.gz -C /var/jenkins_home
kubectl rollout restart -n jenkins deployment/jenkins
```

## Security Best Practices

1. **Enable Authentication**: Configure authentication (LDAP, OAuth, etc.)
2. **Authorization**: Use role-based authorization
3. **Secrets Management**: Use Kubernetes secrets or external secret managers
4. **Network Policies**: Restrict network access to Jenkins
5. **Updates**: Regularly update Jenkins and plugins
6. **Audit Logs**: Enable audit logging

## Troubleshooting

### Pod Won't Start

Check PVC status:
```bash
kubectl get pvc -n jenkins
kubectl describe pvc jenkins-pvc -n jenkins
```

Check pod events:
```bash
kubectl describe pod -n jenkins -l app=jenkins
```

### Permission Issues

Verify ServiceAccount and RBAC:
```bash
kubectl get sa jenkins -n jenkins
kubectl describe clusterrole jenkins
kubectl describe clusterrolebinding jenkins
```

### Agent Connection Issues

Check agent port (50000) connectivity:
```bash
kubectl get svc jenkins-service -n jenkins
kubectl logs -n jenkins deployment/jenkins | grep "agent"
```

### Performance Issues

Increase resource limits or check plugin overhead:
```bash
kubectl top pod -n jenkins
kubectl logs -n jenkins deployment/jenkins | grep -i "memory\|cpu"
```

## Monitoring

### Prometheus Metrics

Install the Prometheus plugin and configure a ServiceMonitor:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: jenkins
  namespace: jenkins
spec:
  selector:
    matchLabels:
      app: jenkins
  endpoints:
  - port: http
    path: /prometheus
```

### Log Aggregation

Jenkins logs are available via kubectl:
```bash
kubectl logs -f -n jenkins deployment/jenkins
```

For centralized logging, configure log forwarding to Elasticsearch/Loki.

## Upgrading Jenkins

1. Update the image tag in kustomization.yaml
2. Apply the changes: `kubectl apply -k infra/base/jenkins/`
3. Monitor the rollout: `kubectl rollout status -n jenkins deployment/jenkins`
4. Verify plugins compatibility after upgrade

## Additional Resources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [Jenkins Configuration as Code](https://www.jenkins.io/projects/jcasc/)
- [Best Practices](https://www.jenkins.io/doc/book/using/best-practices/)
