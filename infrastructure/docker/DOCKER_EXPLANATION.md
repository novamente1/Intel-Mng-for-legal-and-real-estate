# Docker Configuration Explanation

## Overview

Production-ready Docker setup with multi-stage builds, security hardening, and Kubernetes compatibility.

## Multi-Stage Builds

### Node.js API (`Dockerfile.api`)

**4 Stages:**
1. **base** - Node.js 18 Alpine base with security updates
2. **deps** - Install production dependencies only
3. **builder** - Install all dependencies and build application
4. **runner** - Final production image with minimal footprint

**Benefits:**
- Smaller final image (~150MB vs ~500MB)
- No build tools in production
- Faster builds with layer caching
- Security: fewer attack surfaces

### Python Service (`Dockerfile.intelligence`)

**4 Stages:**
1. **base** - Python 3.10 slim with security updates
2. **deps** - Install production dependencies with Poetry
3. **builder** - Build stage for compiled extensions
4. **runner** - Final production image

**Benefits:**
- Optimized for production
- No dev dependencies in runtime
- Smaller image size
- Secure defaults

## Security Features

### 1. Non-Root Users
- **API**: Runs as `nodejs` user (UID 1001)
- **Intelligence**: Runs as `python` user (UID 1001)
- **PostgreSQL**: Runs as `postgres` user (default)
- **Redis**: Runs as `redis` user (default)

### 2. Read-Only Filesystems
- Application code is read-only
- Logs written to tmpfs (in-memory)
- Prevents code modification at runtime

### 3. Security Options
- `no-new-privileges:true` - Prevents privilege escalation
- Minimal base images (Alpine Linux)
- Security updates applied on build

### 4. Network Isolation
- Services communicate via Docker network
- No direct host network access
- Isolated subnet (172.28.0.0/16)

## Health Checks

All services include health checks for orchestration:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD [health_check_command]
```

**Benefits:**
- Automatic restart on failure
- Kubernetes readiness/liveness probes
- Service dependency management
- Monitoring integration

## Docker Compose Configuration

### Production (`docker-compose.yml`)

**Features:**
- Health check dependencies
- Persistent volumes for data
- Secure environment variables
- Restart policies
- Resource isolation

**Service Dependencies:**
```
api → postgres (healthy)
api → redis (healthy)
intelligence → postgres (healthy)
intelligence → redis (healthy)
```

### Development (`docker-compose.dev.yml`)

**Overrides:**
- Volume mounts for live reload
- Development environment variables
- No password for Redis (dev only)
- Read-write filesystems

## Volume Management

**Persistent Data:**
- `postgres_data` - Database files
- `redis_data` - AOF/RDB files

**Logs:**
- `api_logs` - Application logs
- `intelligence_logs` - Service logs

**Development:**
- Source code volumes for hot reload
- Node modules volume for performance

## Kubernetes Readiness

### Compatibility Features

1. **Health Checks** → K8s Probes
   ```yaml
   livenessProbe:
     httpGet:
       path: /health
       port: 3000
   ```

2. **Non-Root Users** → Pod Security
   ```yaml
   securityContext:
     runAsNonRoot: true
     runAsUser: 1001
   ```

3. **Read-Only Filesystem** → Security Context
   ```yaml
   securityContext:
     readOnlyRootFilesystem: true
   ```

4. **Environment Variables** → ConfigMaps/Secrets
   ```yaml
   envFrom:
     - configMapRef:
         name: app-config
     - secretRef:
         name: app-secrets
   ```

5. **Volumes** → PersistentVolumeClaims
   ```yaml
   volumes:
     - name: postgres-data
       persistentVolumeClaim:
         claimName: postgres-pvc
   ```

## Image Optimization

### Size Reduction
- **Alpine base images** - Minimal Linux distribution
- **Multi-stage builds** - Remove build dependencies
- **Layer caching** - Optimize Dockerfile order
- **.dockerignore** - Exclude unnecessary files

### Build Performance
- **Parallel builds** - Independent stages
- **Cache layers** - Reuse unchanged layers
- **Minimal context** - Copy only needed files

## Best Practices Implemented

✅ **Least privilege** - Non-root users
✅ **Minimal attack surface** - Small base images
✅ **Immutable infrastructure** - Read-only filesystems
✅ **Health monitoring** - Built-in health checks
✅ **Secret management** - Environment variables
✅ **Resource limits** - Memory and CPU constraints
✅ **Logging** - Structured log output
✅ **Graceful shutdown** - Signal handling (dumb-init)

## Production Checklist

- [ ] Set secure passwords in environment
- [ ] Use secrets management (not plain env vars)
- [ ] Configure resource limits
- [ ] Set up monitoring and alerting
- [ ] Enable TLS for database connections
- [ ] Configure backup strategies
- [ ] Set up log aggregation
- [ ] Review security policies
- [ ] Test disaster recovery
- [ ] Document deployment procedures


