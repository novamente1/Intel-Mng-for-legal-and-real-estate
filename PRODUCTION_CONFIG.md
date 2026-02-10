# Production Configuration Guide

This document outlines the production-ready features and configuration options for the platform.

## Features Implemented

### 1. Rate Limiting
- **Per-tenant rate limiting**: 1000 requests/minute (configurable)
- **Per-user rate limiting**: 60 requests/minute (configurable)
- **Authentication rate limiting**: 5 attempts per 15 minutes
- **Distributed rate limiting**: Uses Redis for multi-instance deployments
- **Configurable**: Via environment variables

### 2. Background Jobs
- **Bull Queue**: Redis-based job queue system
- **Automatic retries**: Exponential backoff (3 attempts by default)
- **Job persistence**: Keeps last 100 completed, 500 failed jobs
- **Job monitoring**: Event handlers for completed/failed/stalled jobs
- **Timeout protection**: 30-second default timeout per job

### 3. Retry Logic
- **Exponential backoff**: Configurable retry attempts and delays
- **Circuit breaker pattern**: Prevents cascading failures
- **Retryable error detection**: Only retries specific error types
- **Configurable**: Max attempts, delays, backoff multiplier

### 4. Monitoring Hooks
- **Request metrics**: Total, successful, failed requests
- **Performance metrics**: Average, P95, P99, max response times
- **Error tracking**: Error counts by type, recent errors
- **System metrics**: Memory usage, CPU, uptime
- **Database metrics**: Connection pool, query counts
- **Cache metrics**: Hit rate, total keys

### 5. Health Checks
- **Basic health**: `/health` - Simple status check
- **Liveness probe**: `/health/live` - Kubernetes liveness
- **Readiness probe**: `/health/ready` - Kubernetes readiness (checks DB + Redis)
- **Detailed health**: `/health/detailed` - Full service status
- **Prometheus metrics**: `/health/metrics` - Prometheus-compatible format

### 6. Load-Safe Defaults
- **Database connection pooling**: Min 5, Max 20 connections (configurable)
- **Connection timeouts**: 10-second connection timeout
- **Query timeouts**: 30-second statement timeout
- **Redis connection pooling**: Auto-pipelining enabled
- **Keep-alive**: Connection keep-alive for both DB and Redis

## Environment Variables

### Database Configuration
```bash
# Connection pool settings
DB_POOL_MAX=20              # Maximum connections in pool
DB_POOL_MIN=5               # Minimum connections in pool
DB_CONNECTION_TIMEOUT_MS=10000    # Connection timeout
DB_IDLE_TIMEOUT_MS=30000         # Idle connection timeout
DB_STATEMENT_TIMEOUT_MS=30000    # Query timeout
```

### Redis Configuration
```bash
# Redis connection settings
REDIS_MAX_RETRIES=3         # Max retries per request
REDIS_CONNECT_TIMEOUT_MS=10000   # Connection timeout
REDIS_COMMAND_TIMEOUT_MS=5000    # Command timeout
REDIS_KEEPALIVE_MS=30000         # Keep-alive interval
```

### Rate Limiting
```bash
# Rate limit settings
RATE_LIMIT_TENANT_MAX=1000       # Max requests per tenant per window
RATE_LIMIT_TENANT_WINDOW_MS=60000  # Rate limit window (1 minute)
```

### Application
```bash
# Application settings
APP_VERSION=1.0.0           # Application version
NODE_ENV=production          # Environment
```

## Health Check Endpoints

### Basic Health Check
```bash
curl http://localhost:3000/health
```

### Liveness Probe (Kubernetes)
```bash
curl http://localhost:3000/health/live
```

### Readiness Probe (Kubernetes)
```bash
curl http://localhost:3000/health/ready
```

### Detailed Health Check
```bash
curl http://localhost:3000/health/detailed
```

### Prometheus Metrics
```bash
curl http://localhost:3000/health/metrics
```

## Monitoring Endpoints

### Application Metrics
```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/v1/metrics
```

## Background Jobs

### Example: Adding a Job
```typescript
import { JobQueueService } from './services/job-queue';

// Add job to queue
const job = await JobQueueService.addJob('email-queue', {
  to: 'user@example.com',
  subject: 'Welcome',
  body: 'Welcome to the platform',
}, {
  attempts: 3,
  backoff: {
    type: 'exponential',
    delay: 2000,
  },
});

// Process jobs
JobQueueService.processQueue('email-queue', async (job) => {
  // Process job
  return { success: true, data: 'Job completed' };
});
```

## Retry Logic

### Example: Using Retry Service
```typescript
import { RetryService } from './services/retry';

// Execute with retry
const result = await RetryService.execute(
  async () => {
    // Operation that might fail
    return await someOperation();
  },
  {
    maxAttempts: 3,
    initialDelayMs: 1000,
    backoffMultiplier: 2,
    retryableErrors: ['ECONNREFUSED', 'ETIMEDOUT'],
  }
);

// Circuit breaker
const circuitBreaker = RetryService.createCircuitBreaker({
  failureThreshold: 5,
  resetTimeoutMs: 60000,
});

const result = await circuitBreaker(async () => {
  return await externalServiceCall();
});
```

## Rate Limiting

### Example: Using Rate Limit Middleware
```typescript
import { rateLimit, userRateLimit, authRateLimit } from './middleware/rate-limit';

// Global rate limit
app.use(rateLimit({
  windowMs: 60000,
  maxRequests: 100,
}));

// Per-user rate limit
app.use('/api', userRateLimit(60, 60000));

// Auth endpoint rate limit
app.use('/auth/login', authRateLimit());
```

## Production Deployment Checklist

- [ ] Set all environment variables
- [ ] Configure database connection pool sizes
- [ ] Configure Redis connection settings
- [ ] Set up rate limiting thresholds
- [ ] Configure health check endpoints in load balancer
- [ ] Set up monitoring/alerting for metrics
- [ ] Configure background job workers
- [ ] Set up log aggregation
- [ ] Configure graceful shutdown handlers
- [ ] Test health checks
- [ ] Test rate limiting
- [ ] Test background jobs
- [ ] Test retry logic
- [ ] Load test the system

## Kubernetes Deployment

### Liveness Probe
```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10
```

### Readiness Probe
```yaml
readinessProbe:
  httpGet:
    path: /health/ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
```

## Monitoring Integration

### Prometheus
The `/health/metrics` endpoint provides Prometheus-compatible metrics:
- `nodejs_heap_size_total_bytes`
- `nodejs_heap_size_used_bytes`
- `nodejs_external_memory_bytes`
- `nodejs_process_uptime_seconds`
- `http_requests_total`

### Custom Metrics
Access application metrics via `/api/v1/metrics` endpoint (requires authentication).

## Performance Tuning

### Database
- Adjust `DB_POOL_MAX` based on expected load
- Monitor connection pool usage
- Set appropriate `DB_STATEMENT_TIMEOUT_MS`

### Redis
- Enable auto-pipelining (already enabled)
- Monitor connection pool
- Set appropriate timeouts

### Rate Limiting
- Adjust per-tenant limits based on subscription tier
- Monitor rate limit violations
- Adjust window sizes for different endpoints

## Security Considerations

1. **Rate Limiting**: Prevents DDoS and brute force attacks
2. **Connection Limits**: Prevents resource exhaustion
3. **Timeouts**: Prevents hanging connections
4. **Circuit Breakers**: Prevents cascading failures
5. **Health Checks**: Don't expose sensitive information

## Troubleshooting

### High Rate Limit Errors
- Check if legitimate traffic or attack
- Adjust rate limit thresholds
- Monitor per-tenant usage

### Database Connection Pool Exhausted
- Increase `DB_POOL_MAX`
- Check for connection leaks
- Monitor query performance

### Background Jobs Failing
- Check Redis connectivity
- Review job error logs
- Adjust retry settings

### Health Checks Failing
- Check database connectivity
- Check Redis connectivity
- Review service logs
