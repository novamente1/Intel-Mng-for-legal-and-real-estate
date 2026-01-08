# Redis Integration

## Overview

Redis integration for session caching, distributed locks, and rate limiting. Redis is used as a **supporting layer**, not primary storage.

## Features

✅ **Session Caching** - User session data caching
✅ **Distributed Locks** - Prevent concurrent edits with auto-expiration
✅ **Rate Limiting** - Distributed rate limiting using Redis
✅ **Auto-Expiration** - All locks automatically expire to prevent deadlocks
✅ **Fail-Safe** - Gracefully handles Redis unavailability

## Components

### 1. Redis Client (`src/services/redis.ts`)

Singleton Redis client with connection management.

**Features:**
- Connection pooling
- Automatic reconnection
- Health checks
- Graceful shutdown

**Usage:**
```typescript
import { redisClient } from './services/redis';

// Initialize (called in app.ts)
redisClient.initialize();

// Check availability
if (redisClient.isAvailable()) {
  const client = redisClient.getClient();
  // Use client
}
```

### 2. Session Cache Service (`src/services/session-cache.ts`)

Manages user session data in Redis.

**Methods:**
- `setSession()` - Store session data
- `getSession()` - Retrieve session data
- `deleteSession()` - Delete session
- `deleteUserSessions()` - Delete all user sessions
- `refreshSession()` - Refresh session TTL
- `getUserSessionCount()` - Get session count

**Usage:**
```typescript
import { SessionCacheService } from './services/session-cache';

// Store session
await SessionCacheService.setSession(sessionId, {
  userId: user.id,
  email: user.email,
  roles: ['admin'],
}, 3600); // 1 hour TTL

// Get session
const session = await SessionCacheService.getSession(sessionId);

// Delete session
await SessionCacheService.deleteSession(sessionId, userId);
```

### 3. Distributed Lock Service (`src/services/distributed-lock.ts`)

Implements distributed locks with auto-expiration.

**Methods:**
- `acquireLock()` - Acquire a lock
- `releaseLock()` - Release a lock
- `extendLock()` - Extend lock TTL
- `isLocked()` - Check if locked
- `getLockTTL()` - Get remaining TTL
- `withLock()` - Execute function with lock

**Usage:**
```typescript
import { DistributedLockService } from './services/distributed-lock';

// Manual lock management
const lockToken = await DistributedLockService.acquireLock('process:123', 300);
if (lockToken) {
  try {
    // Perform operation
  } finally {
    await DistributedLockService.releaseLock('process:123', lockToken);
  }
}

// Automatic lock management
await DistributedLockService.withLock(
  'process:123',
  async () => {
    // Perform operation - lock automatically acquired and released
  },
  300 // 5 minutes TTL
);
```

### 4. Rate Limiting Middleware (`src/middleware/rate-limit-redis.ts`)

Redis-based rate limiting middleware.

**Usage:**
```typescript
import { rateLimitRedis } from './middleware/rate-limit-redis';

router.use(rateLimitRedis({
  windowMs: 15 * 60 * 1000, // 15 minutes
  maxRequests: 100,
  keyGenerator: (req) => req.user?.id || req.ip,
  message: 'Too many requests',
}));
```

## Process Locking Example

See `src/routes/process-lock-example.ts` for complete examples:

### Acquire Lock
```typescript
POST /api/v1/processes/:id/lock
Headers: Authorization: Bearer <token>
Response: { lockToken, expiresIn }
```

### Update with Lock
```typescript
PUT /api/v1/processes/:id
Headers: 
  Authorization: Bearer <token>
  X-Lock-Token: <lockToken>
Body: { title, status, description }
```

### Automatic Lock Management
```typescript
PATCH /api/v1/processes/:id/quick-update
Headers: Authorization: Bearer <token>
Body: { title, status }
// Lock automatically acquired and released
```

### Check Lock Status
```typescript
GET /api/v1/processes/:id/lock/status
Headers: Authorization: Bearer <token>
Response: { isLocked, ttl, expiresIn }
```

### Extend Lock
```typescript
POST /api/v1/processes/:id/lock/extend
Headers: 
  Authorization: Bearer <token>
  X-Lock-Token: <lockToken>
Body: { ttl: 300 }
```

## Configuration

Environment variables:

```env
# Redis Configuration
REDIS_ENABLED=true
REDIS_URL=redis://localhost:6379
# OR
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=your-password
REDIS_DB=0
```

## Lock Auto-Expiration

All locks automatically expire to prevent deadlocks:

- **Default TTL**: 30 seconds
- **Process locks**: 5 minutes (300 seconds)
- **Quick updates**: 1 minute (60 seconds)

Locks can be extended using `extendLock()` method.

## Security

1. **Token-based locks** - Each lock has a unique token
2. **Atomic operations** - Lua scripts ensure atomicity
3. **Token verification** - Only lock owner can release/extend
4. **Auto-expiration** - Prevents deadlocks

## Error Handling

- Redis unavailability is handled gracefully
- Services fail open (allow operations if Redis unavailable)
- Logs errors but doesn't break application
- Fallback behavior when Redis is down

## Performance

- Non-blocking operations
- Connection pooling
- Efficient data structures (sorted sets for rate limiting)
- Minimal overhead

## File Structure

```
src/
├── services/
│   ├── redis.ts              # Redis client
│   ├── session-cache.ts      # Session caching
│   └── distributed-lock.ts   # Distributed locks
├── middleware/
│   └── rate-limit-redis.ts   # Rate limiting
└── routes/
    └── process-lock-example.ts # Process locking examples
```

