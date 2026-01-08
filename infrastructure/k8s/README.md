# Kubernetes Configuration

Minimal Kubernetes setup for GKE (Google Kubernetes Engine) with managed external services.

## Overview

This directory contains Kubernetes manifests for:
- **API Service** - Node.js backend API
- **Intelligence Service** - Python ML service
- **PostgreSQL** - Managed via Cloud SQL (external)
- **Redis** - Managed via Memorystore (external)

## Prerequisites

- GKE cluster running
- `kubectl` configured
- GCP project with appropriate permissions
- Cloud SQL instance created
- Memorystore instance created
- Container images pushed to GCR

## File Structure

```
k8s/
├── namespace.yaml              # Platform namespace
├── configmap.yaml              # Non-sensitive configuration
├── secrets.yaml                # Sensitive data (placeholders)
├── serviceaccount.yaml         # Service accounts
├── api/
│   ├── deployment.yaml         # API deployment
│   └── service.yaml            # API service
├── intelligence/
│   ├── deployment.yaml         # Intelligence deployment
│   └── service.yaml            # Intelligence service
├── ingress.yaml                # Ingress and SSL
├── hpa.yaml                    # Horizontal Pod Autoscalers
├── pdb.yaml                    # Pod Disruption Budgets
└── README.md                   # This file
```

## Resources Explained

### 1. Namespace (`namespace.yaml`)

**Purpose:** Isolates platform resources from other workloads.

**Key Points:**
- Namespace: `platform`
- Labels for organization and filtering

### 2. ConfigMap (`configmap.yaml`)

**Purpose:** Stores non-sensitive configuration data.

**Contains:**
- Application settings (ports, log levels)
- Feature flags
- External service endpoints (placeholders)
- Rate limiting configuration

**Note:** Replace `PLACEHOLDER_*` values with actual Cloud SQL and Memorystore details.

### 3. Secrets (`secrets.yaml`)

**Purpose:** Stores sensitive data (passwords, tokens, connection strings).

**Contains:**
- Database credentials
- JWT secrets
- Redis passwords
- Connection strings

**⚠️ Important:** 
- Replace all `PLACEHOLDER_*` values
- Use GCP Secret Manager in production
- Consider External Secrets Operator for automatic sync

### 4. Service Accounts (`serviceaccount.yaml`)

**Purpose:** Provides identity for pods to access GCP services.

**Usage:**
- Workload Identity for Cloud SQL proxy
- Service account for GCR image pulling
- IAM bindings for GCP resources

### 5. API Deployment (`api/deployment.yaml`)

**Purpose:** Defines the API service pods.

**Features:**
- 3 replicas (minimum)
- Rolling update strategy
- Resource limits (256Mi-512Mi memory, 250m-500m CPU)
- Health checks (liveness and readiness)
- Security context (non-root, read-only filesystem)
- Environment variables from ConfigMap and Secrets

**Key Configuration:**
- Image: `gcr.io/PROJECT_ID/platform-api:latest`
- Port: 3000
- Health endpoints: `/health/live`, `/health/ready`

### 6. API Service (`api/service.yaml`)

**Purpose:** Exposes API pods internally via ClusterIP.

**Features:**
- ClusterIP (internal only)
- Session affinity for stateful operations
- Port 80 → 3000 mapping

### 7. Intelligence Deployment (`intelligence/deployment.yaml`)

**Purpose:** Defines the Python ML service pods.

**Features:**
- 2 replicas (minimum)
- Higher resource limits (512Mi-1Gi memory, 500m-1000m CPU)
- Health checks
- Security context
- Python-specific environment variables

**Key Configuration:**
- Image: `gcr.io/PROJECT_ID/platform-intelligence:latest`
- Port: 8000
- Health endpoint: `/health`

### 8. Intelligence Service (`intelligence/service.yaml`)

**Purpose:** Exposes intelligence pods internally.

**Features:**
- ClusterIP (internal only)
- Port 80 → 8000 mapping

### 9. Ingress (`ingress.yaml`)

**Purpose:** Exposes services externally with SSL/TLS.

**Features:**
- GKE Ingress Controller
- Managed SSL certificates
- Backend configuration for health checks
- Multiple hostnames (api.*, intelligence.*)

**GCP Resources Required:**
- Static IP address
- Managed SSL certificate
- Backend config

### 10. Horizontal Pod Autoscaler (`hpa.yaml`)

**Purpose:** Automatically scales pods based on CPU/memory usage.

**API HPA:**
- Min: 3 replicas
- Max: 10 replicas
- CPU target: 70%
- Memory target: 80%

**Intelligence HPA:**
- Min: 2 replicas
- Max: 5 replicas
- CPU target: 70%
- Memory target: 80%

### 11. Pod Disruption Budget (`pdb.yaml`)

**Purpose:** Ensures minimum availability during maintenance.

**API PDB:**
- Minimum 2 pods available

**Intelligence PDB:**
- Minimum 1 pod available

## Deployment Steps

### 1. Replace Placeholders

**In `secrets.yaml`:**
```yaml
DATABASE_URL: "postgresql://user:password@/cloudsql/PROJECT:REGION:INSTANCE/dbname"
JWT_SECRET: "your-actual-secret-min-32-chars"
REDIS_PASSWORD: "your-redis-password"
```

**In `configmap.yaml`:**
```yaml
DATABASE_HOST: "PROJECT:REGION:INSTANCE"
REDIS_HOST: "10.x.x.x"  # Memorystore IP
```

**In deployment files:**
```yaml
image: gcr.io/YOUR_PROJECT_ID/platform-api:latest
```

### 2. Create GCP Resources

```bash
# Cloud SQL instance (if not exists)
gcloud sql instances create platform-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-central1

# Memorystore instance (if not exists)
gcloud redis instances create platform-redis \
  --size=1 \
  --region=us-central1

# Static IP
gcloud compute addresses create platform-static-ip --global
```

### 3. Push Container Images

```bash
# Build and push API
docker build -t gcr.io/PROJECT_ID/platform-api:latest -f infrastructure/docker/Dockerfile.api .
docker push gcr.io/PROJECT_ID/platform-api:latest

# Build and push Intelligence
docker build -t gcr.io/PROJECT_ID/platform-intelligence:latest -f infrastructure/docker/Dockerfile.intelligence .
docker push gcr.io/PROJECT_ID/platform-intelligence:latest
```

### 4. Apply Kubernetes Manifests

```bash
# Apply in order
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f api/
kubectl apply -f intelligence/
kubectl apply -f ingress.yaml
kubectl apply -f hpa.yaml
kubectl apply -f pdb.yaml

# Or apply all at once
kubectl apply -f .
```

### 5. Verify Deployment

```bash
# Check pods
kubectl get pods -n platform

# Check services
kubectl get svc -n platform

# Check ingress
kubectl get ingress -n platform

# View logs
kubectl logs -f deployment/api -n platform
```

## External Services Configuration

### Cloud SQL Connection

**Option 1: Cloud SQL Proxy (Recommended)**
- Add Cloud SQL Proxy sidecar to deployments
- Use Workload Identity for authentication
- Connection: `postgresql://user:pass@localhost:5432/dbname`

**Option 2: Private IP**
- Enable private IP on Cloud SQL
- Use VPC-native GKE cluster
- Connection: `postgresql://user:pass@PRIVATE_IP:5432/dbname`

### Memorystore Connection

**Private IP Connection:**
- Memorystore provides private IP in VPC
- Use VPC-native GKE cluster
- Connection: `redis://:password@MEMORYSTORE_IP:6379/0`

## Security Best Practices

1. **Secrets Management:**
   - Use GCP Secret Manager
   - Implement External Secrets Operator
   - Rotate secrets regularly

2. **Network Security:**
   - Use private GKE clusters
   - Enable network policies
   - Restrict ingress to specific IPs

3. **Pod Security:**
   - Non-root users (enforced)
   - Read-only filesystems (enforced)
   - Drop all capabilities (enforced)

4. **RBAC:**
   - Least privilege service accounts
   - Workload Identity for GCP access
   - Minimal cluster roles

## Monitoring

**Recommended:**
- GKE monitoring (built-in)
- Prometheus + Grafana
- Cloud Logging
- Cloud Trace

**Annotations:**
- Pods include Prometheus scrape annotations
- Health check endpoints for monitoring

## Troubleshooting

```bash
# Describe pod
kubectl describe pod <pod-name> -n platform

# Check events
kubectl get events -n platform --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n platform

# Exec into pod
kubectl exec -it <pod-name> -n platform -- sh

# Check resource usage
kubectl top pods -n platform
```

## Production Checklist

- [ ] Replace all placeholders
- [ ] Configure Cloud SQL connection
- [ ] Configure Memorystore connection
- [ ] Set up Workload Identity
- [ ] Configure SSL certificates
- [ ] Set up monitoring and alerting
- [ ] Configure backup strategies
- [ ] Review resource limits
- [ ] Test scaling behavior
- [ ] Document runbooks
- [ ] Set up CI/CD pipeline

