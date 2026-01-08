# Kubernetes Resources Explanation

## Overview

Minimal Kubernetes setup for GKE with managed external services (Cloud SQL, Memorystore).

## Resource Breakdown

### Core Resources

#### 1. **Namespace** (`namespace.yaml`)
- **Purpose:** Logical isolation of platform resources
- **Why:** Prevents conflicts, enables resource quotas, simplifies management
- **Usage:** All resources belong to `platform` namespace

#### 2. **ConfigMap** (`configmap.yaml`)
- **Purpose:** Non-sensitive configuration storage
- **Contains:** Ports, log levels, feature flags, external service endpoints
- **Why:** Separates config from code, enables environment-specific configs
- **Note:** Contains placeholders for Cloud SQL and Memorystore

#### 3. **Secrets** (`secrets.yaml`)
- **Purpose:** Sensitive data storage (encrypted at rest)
- **Contains:** Passwords, tokens, connection strings
- **Why:** Secure credential management
- **⚠️ Important:** Replace placeholders, use Secret Manager in production

#### 4. **ServiceAccount** (`serviceaccount.yaml`)
- **Purpose:** Pod identity for GCP service access
- **Why:** Enables Workload Identity, IAM bindings
- **Usage:** Each service has its own service account

### API Service

#### 5. **API Deployment** (`api/deployment.yaml`)
- **Purpose:** Defines API pod specifications
- **Replicas:** 3 (minimum for HA)
- **Strategy:** Rolling update (zero downtime)
- **Resources:** 256Mi-512Mi memory, 250m-500m CPU
- **Security:** Non-root user, read-only filesystem, dropped capabilities
- **Health Checks:**
  - Liveness: `/health/live` (restart if unhealthy)
  - Readiness: `/health/ready` (traffic routing)
- **Environment:** Mix of ConfigMap and Secret values

#### 6. **API Service** (`api/service.yaml`)
- **Purpose:** Internal service discovery
- **Type:** ClusterIP (internal only)
- **Port:** 80 → 3000
- **Session Affinity:** Enabled for stateful operations

### Intelligence Service

#### 7. **Intelligence Deployment** (`intelligence/deployment.yaml`)
- **Purpose:** Defines Python ML service pods
- **Replicas:** 2 (minimum)
- **Resources:** 512Mi-1Gi memory, 500m-1000m CPU (ML workloads need more)
- **Security:** Same as API (non-root, read-only)
- **Health Checks:** `/health` endpoint

#### 8. **Intelligence Service** (`intelligence/service.yaml`)
- **Purpose:** Internal service discovery
- **Type:** ClusterIP
- **Port:** 80 → 8000

### Networking

#### 9. **Ingress** (`ingress.yaml`)
- **Purpose:** External access with SSL/TLS
- **Controller:** GKE Ingress (GCE)
- **Features:**
  - Managed SSL certificates
  - Static IP
  - Backend configuration
  - Multiple hostnames
- **GCP Resources:**
  - ManagedCertificate (automatic SSL)
  - BackendConfig (health checks, timeouts)

### Autoscaling

#### 10. **Horizontal Pod Autoscaler** (`hpa.yaml`)
- **Purpose:** Automatic scaling based on metrics
- **API HPA:**
  - Scale: 3-10 pods
  - Metrics: CPU (70%), Memory (80%)
  - Behavior: Aggressive scale-up, conservative scale-down
- **Intelligence HPA:**
  - Scale: 2-5 pods
  - Same metrics and behavior

### High Availability

#### 11. **Pod Disruption Budget** (`pdb.yaml`)
- **Purpose:** Ensures minimum availability during maintenance
- **API PDB:** Min 2 pods available
- **Intelligence PDB:** Min 1 pod available
- **Why:** Prevents all pods from being evicted simultaneously

## External Services

### Cloud SQL (PostgreSQL)
- **Managed Service:** GCP Cloud SQL
- **Connection Options:**
  1. Cloud SQL Proxy (sidecar) - Recommended
  2. Private IP (VPC-native cluster)
- **Authentication:** Workload Identity
- **Configuration:** Connection string in Secret

### Memorystore (Redis)
- **Managed Service:** GCP Memorystore
- **Connection:** Private IP in VPC
- **Authentication:** Password in Secret
- **Configuration:** Host and password in ConfigMap/Secret

## Security Features

### Pod Security
- ✅ Non-root users (UID 1001)
- ✅ Read-only root filesystem
- ✅ Dropped capabilities
- ✅ Seccomp profile (RuntimeDefault)

### Network Security
- ✅ ClusterIP services (internal only)
- ✅ Ingress with SSL/TLS
- ✅ Private GKE cluster (recommended)
- ✅ Network policies (can be added)

### Secret Management
- ✅ Kubernetes Secrets (encrypted at rest)
- ⚠️ Use GCP Secret Manager in production
- ⚠️ Consider External Secrets Operator

## GCP Integration

### Required GCP Resources
1. **GKE Cluster** - VPC-native, private nodes recommended
2. **Cloud SQL** - PostgreSQL instance
3. **Memorystore** - Redis instance
4. **Static IP** - For Ingress
5. **Managed Certificate** - For SSL (via Ingress)

### Workload Identity
- Service accounts mapped to GCP IAM
- No service account keys needed
- Secure access to GCP services

## Deployment Flow

1. **Create GCP Resources** (Cloud SQL, Memorystore, Static IP)
2. **Build and Push Images** to GCR
3. **Update Placeholders** in manifests
4. **Apply Manifests** in order
5. **Verify Deployment** (pods, services, ingress)
6. **Monitor** (logs, metrics, health)

## Best Practices Implemented

✅ **Multi-replica deployments** - High availability
✅ **Resource limits** - Prevent resource exhaustion
✅ **Health checks** - Automatic recovery
✅ **Rolling updates** - Zero downtime
✅ **Horizontal scaling** - Handle load
✅ **Pod disruption budgets** - Maintain availability
✅ **Security hardening** - Non-root, read-only, dropped caps
✅ **Secret separation** - Config vs secrets
✅ **Namespace isolation** - Resource organization

## Production Considerations

1. **Use Secret Manager** instead of Kubernetes Secrets
2. **Enable Network Policies** for pod-to-pod communication
3. **Set up Monitoring** (Prometheus, Grafana, Cloud Monitoring)
4. **Configure Backups** (Cloud SQL automated backups)
5. **Implement CI/CD** (GitOps with ArgoCD or similar)
6. **Review Resource Limits** based on actual usage
7. **Set up Alerts** for critical metrics
8. **Document Runbooks** for common issues

