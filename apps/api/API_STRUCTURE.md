# API Structure & Key Files

## Framework Choice: Express.js

**Justification:**
- **Ecosystem**: Largest middleware ecosystem (helmet, cors, rate-limit, etc.)
- **Maturity**: Battle-tested in production for 15+ years
- **Flexibility**: Unopinionated, allows architectural freedom
- **RBAC/Audit Ready**: Extensive middleware ecosystem perfect for security features
- **Team Familiarity**: Most developers are familiar with Express
- **Performance**: Sufficient for SaaS applications (can optimize later if needed)

## File Structure

```
apps/api/
├── src/
│   ├── app.ts                    # Application factory & server setup
│   ├── index.ts                  # Entry point
│   │
│   ├── config/                   # Configuration management
│   │   ├── env.ts                # Environment validation with Zod
│   │   └── index.ts              # Config exports
│   │
│   ├── middleware/               # Express middleware
│   │   ├── errorHandler.ts       # Centralized error handling
│   │   ├── logger.ts             # Request logging & request ID
│   │   ├── validator.ts          # Zod-based request validation
│   │   ├── security.ts           # Security middleware (helmet, CORS, etc.)
│   │   └── index.ts              # Middleware exports
│   │
│   ├── routes/                   # API routes
│   │   ├── health.ts             # Health check endpoints
│   │   └── index.ts              # Route registration
│   │
│   ├── utils/                    # Utilities
│   │   ├── logger.ts             # Winston logger setup
│   │   └── errors.ts             # Custom error classes
│   │
│   ├── services/                 # Business logic (future)
│   ├── models/                   # Data models (future)
│   ├── types/                    # TypeScript types (future)
│   ├── rbac/                     # RBAC module (future)
│   ├── audit/                    # Audit logging (future)
│   └── workflow/                 # Workflow engine (future)
│
├── package.json                  # Dependencies & scripts
├── tsconfig.json                 # TypeScript configuration
├── .eslintrc.json                # ESLint configuration
├── .env.example                  # Environment variables template
└── README.md                     # API documentation
```

## Key Configuration Files

### 1. `src/config/env.ts`
**Environment-based configuration with validation**

- Uses Zod for type-safe environment variable validation
- Validates all required variables at startup
- Provides structured config object
- Ready for future additions (database, RBAC, audit)

**Features:**
- Type-safe configuration
- Validation on startup (fails fast if config is invalid)
- Environment-specific defaults
- Extensible for future features

### 2. `src/middleware/errorHandler.ts`
**Centralized error handling**

- Custom error classes (`AppError`, `ValidationError`, `NotFoundError`, etc.)
- Consistent error response format
- Proper HTTP status codes
- Error logging with context

**Error Classes:**
- `ValidationError` (400) - Request validation failures
- `AuthenticationError` (401) - Authentication required
- `AuthorizationError` (403) - Insufficient permissions
- `NotFoundError` (404) - Resource not found
- `ConflictError` (409) - Resource conflicts
- `InternalServerError` (500) - Unexpected errors

### 3. `src/middleware/validator.ts`
**Request validation layer**

- Zod-based validation middleware
- Validates body, query, and params
- Detailed error messages
- Type-safe validated data

**Usage:**
```typescript
import { validateRequest } from '../middleware';
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
});

router.post('/', validateRequest({ body: schema }), handler);
```

### 4. `src/middleware/logger.ts`
**Structured logging middleware**

- Request/response logging
- Unique request ID for tracing
- Structured JSON logs in production
- Human-readable logs in development

**Features:**
- Request ID generation
- Response time tracking
- Structured log format
- Environment-specific formatting

### 5. `src/utils/logger.ts`
**Winston logger setup**

- Structured logging with Winston
- Different formats for dev/prod
- File logging in production
- Error and rejection handlers

**Log Levels:**
- `error` - Errors only
- `warn` - Warnings and errors
- `info` - Informational messages (default)
- `debug` - Detailed debugging

### 6. `src/middleware/security.ts`
**Security middleware**

- Helmet for HTTP headers
- CORS configuration
- Compression
- Rate limiting

**Security Features:**
- Content Security Policy (production)
- CORS with configurable origins
- Response compression
- Rate limiting per IP

### 7. `src/app.ts`
**Application factory**

- Separated for testing
- Middleware registration
- Route mounting
- Error handler setup
- Graceful shutdown

**Features:**
- Modular application creation
- Graceful shutdown handlers
- Environment-aware configuration
- Clean separation of concerns

## Health Check Endpoint

### `GET /health`
Basic health check endpoint

**Response:**
```json
{
  "success": true,
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "uptime": 123.456,
  "environment": "development",
  "version": "v1",
  "service": "api"
}
```

### `GET /health/ready`
Kubernetes readiness probe

**Response (200):**
```json
{
  "success": true,
  "status": "ready",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### `GET /health/live`
Kubernetes liveness probe

**Response (200):**
```json
{
  "success": true,
  "status": "alive",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

## Extensibility for RBAC & Audit

### RBAC Ready
- `src/rbac/` directory structure in place
- `packages/types/src/rbac/` for shared types
- Error classes ready (`AuthorizationError`)
- Middleware pattern established for auth middleware

### Audit Logging Ready
- `src/audit/` directory structure in place
- `packages/types/src/audit/` for shared types
- Request ID middleware for tracing
- Structured logging foundation
- Error logging with context

### Workflow Engine Ready
- `src/workflow/` directory structure in place
- `packages/types/src/workflow/` for shared types
- Service layer pattern for workflow integration
- Async handler support for long-running operations

## Best Practices Implemented

✅ **Environment-based configuration** with validation
✅ **Centralized error handling** with custom error classes
✅ **Request validation** with Zod schemas
✅ **Structured logging** with Winston
✅ **Security middleware** (helmet, CORS, rate limiting)
✅ **Type safety** throughout with TypeScript
✅ **Modular architecture** for easy extension
✅ **Graceful shutdown** handling
✅ **Request tracing** with unique IDs
✅ **Clean code** with separation of concerns

