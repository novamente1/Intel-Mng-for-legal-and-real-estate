# Docker Configuration

Production-ready Docker setup with multi-stage builds, security hardening, and Kubernetes readiness.

## Overview

This directory contains Docker configurations for:
- **Node.js API** - Backend API service
- **Python Intelligence Service** - AI/ML services
- **PostgreSQL** - Primary database
- **Redis** - Cache and session store

## Features

✅ **Multi-stage builds** - Optimized image sizes
✅ **Security hardening** - Non-root users, read-only filesystems
✅ **Health checks** - Built-in health monitoring
✅ **Production-ready** - Secure defaults and best practices
✅ **Kubernetes-ready** - Compatible with K8s deployments

## Files

- `Dockerfile.api` - Node.js API container
- `Dockerfile.intelligence` - Python service container
- `Dockerfile.postgres` - PostgreSQL database container
- `Dockerfile.redis` - Redis cache container
- `docker-compose.yml` - Production compose file
- `docker-compose.dev.yml` - Development override
- `.dockerignore` - Exclude files from builds

## Quick Start

### Production

```bash
# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Development

```bash
# Use development override
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

## Security Features

### All Services
- **Non-root users** - Services run as non-privileged users
- **Security updates** - Base images updated on build
- **Read-only filesystems** - Where possible
- **No new privileges** - Security opt prevents privilege escalation
- **Health checks** - Built-in monitoring

### Node.js API
- Multi-stage build reduces image size
- Production dependencies only
- Non-root user (nodejs:1001)
- Read-only filesystem with tmpfs for logs

### Python Service
- Multi-stage build
- Production dependencies only
- Non-root user (python:1001)
- Read-only filesystem with tmpfs for logs

### PostgreSQL
- Official PostgreSQL image
- SCRAM-SHA-256 authentication
- Persistent data volumes
- Health checks

### Redis
- Official Redis image
- Password protection
- AOF persistence
- Memory limits and eviction policies

## Environment Variables

Create a `.env` file in the project root:

```env
# Database
POSTGRES_USER=platform_user
POSTGRES_PASSWORD=secure_password_here
POSTGRES_DB=platform_db
POSTGRES_PORT=5432

# Redis
REDIS_PASSWORD=secure_password_here
REDIS_PORT=6379
REDIS_DB=0

# API
API_PORT=3000
JWT_SECRET=your_secret_key_min_32_characters
LOG_LEVEL=info

# Intelligence Service
INTELLIGENCE_PORT=8000
```

## Volumes

Data persistence:
- `postgres_data` - PostgreSQL data directory
- `redis_data` - Redis AOF and RDB files
- `api_logs` - API application logs
- `intelligence_logs` - Intelligence service logs

## Networking

All services are on the `platform-network` bridge network:
- Services can communicate by service name
- Isolated from host network
- Subnet: 172.28.0.0/16

## Health Checks

All services include health checks:
- **PostgreSQL**: `pg_isready` command
- **Redis**: `redis-cli ping`
- **API**: HTTP GET `/health`
- **Intelligence**: HTTP GET `/health`

## Kubernetes Readiness

These Dockerfiles are designed for Kubernetes:
- Health checks map to K8s liveness/readiness probes
- Non-root users for Pod Security Policies
- Read-only filesystems where possible
- Environment variable configuration
- Stateless design (data in volumes)

## Building Images

```bash
# Build all images
docker-compose build

# Build specific service
docker-compose build api

# Build with no cache
docker-compose build --no-cache
```

## Image Sizes

Optimized multi-stage builds result in:
- **API**: ~150MB (alpine base)
- **Intelligence**: ~200MB (slim base)
- **PostgreSQL**: ~200MB (official image)
- **Redis**: ~30MB (alpine base)

## Troubleshooting

### Check service health
```bash
docker-compose ps
```

### View service logs
```bash
docker-compose logs api
docker-compose logs postgres
```

### Access service shell
```bash
docker-compose exec api sh
docker-compose exec postgres psql -U platform_user -d platform_db
```

### Reset volumes
```bash
docker-compose down -v
```

## Production Deployment

1. Set secure environment variables
2. Use secrets management (Docker secrets, K8s secrets)
3. Configure proper resource limits
4. Set up monitoring and logging
5. Use orchestration (Kubernetes, Docker Swarm)
6. Enable TLS/SSL for database connections
7. Configure backup strategies

