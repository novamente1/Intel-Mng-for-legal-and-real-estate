# Backend API

Production-ready Node.js + TypeScript API built with Express.

## Framework Choice: Express

**Justification:**
- **Ecosystem**: Largest middleware ecosystem and community support
- **Maturity**: Battle-tested in production for over a decade
- **Flexibility**: Unopinionated, allows architectural freedom
- **RBAC/Audit Ready**: Extensive middleware ecosystem for security features
- **Team Familiarity**: Most developers are familiar with Express
- **Performance**: Sufficient for most SaaS applications (can optimize later if needed)

## Architecture

### Key Features

- ✅ **Environment-based Configuration**: Type-safe config with Zod validation
- ✅ **Centralized Error Handling**: Custom error classes with consistent responses
- ✅ **Request Validation**: Zod-based validation middleware
- ✅ **Structured Logging**: Winston with JSON logs in production
- ✅ **Security Middleware**: Helmet, CORS, rate limiting, compression
- ✅ **Extensible**: Ready for RBAC, audit logging, and workflow engines

### Project Structure

```
src/
├── app.ts              # Application factory and server setup
├── index.ts            # Entry point
├── config/             # Configuration management
│   ├── env.ts          # Environment validation with Zod
│   └── index.ts
├── middleware/         # Express middleware
│   ├── errorHandler.ts # Centralized error handling
│   ├── logger.ts       # Request logging
│   ├── validator.ts    # Request validation
│   ├── security.ts     # Security middleware
│   └── index.ts
├── routes/             # API routes
│   ├── health.ts       # Health check endpoints
│   └── index.ts
├── services/           # Business logic (future)
├── models/             # Data models (future)
├── utils/              # Utilities
│   ├── logger.ts       # Winston logger setup
│   └── errors.ts       # Custom error classes
├── rbac/               # RBAC module (future)
├── audit/              # Audit logging (future)
└── workflow/           # Workflow engine (future)
```

## Getting Started

### Prerequisites

- Node.js >= 18.0.0
- npm >= 9.0.0

### Installation

```bash
# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Start development server
npm run dev
```

### Environment Variables

See `.env.example` for all available configuration options.

Required:
- `NODE_ENV`: Environment (development, production, test)
- `PORT`: Server port (default: 3000)

Optional:
- `LOG_LEVEL`: Logging level (error, warn, info, debug)
- `CORS_ORIGIN`: CORS allowed origins
- `RATE_LIMIT_WINDOW_MS`: Rate limit window in milliseconds
- `RATE_LIMIT_MAX_REQUESTS`: Max requests per window

## API Endpoints

### Health Check

```bash
# Basic health check
GET /health

# Kubernetes readiness probe
GET /health/ready

# Kubernetes liveness probe
GET /health/live
```

### API Info

```bash
GET /api/v1
```

## Development

### Scripts

- `npm run dev` - Start development server with hot reload
- `npm run build` - Build TypeScript to JavaScript
- `npm run start` - Start production server
- `npm run lint` - Lint code
- `npm run type-check` - Type check without building
- `npm run test` - Run tests

### Adding New Routes

1. Create route file in `src/routes/`
2. Export router from route file
3. Import and register in `src/routes/index.ts`

Example:

```typescript
// src/routes/users.ts
import { Router } from 'express';
import { validateRequest, asyncHandler } from '../middleware';
import { z } from 'zod';

const router = Router();

const createUserSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
});

router.post(
  '/',
  validateRequest({ body: createUserSchema }),
  asyncHandler(async (req, res) => {
    // Handler logic
    res.json({ success: true });
  })
);

export default router;
```

## Error Handling

All errors are handled centrally through the error handler middleware. Use custom error classes:

```typescript
import { ValidationError, NotFoundError } from '../utils/errors';

// Throw validation error
throw new ValidationError('Invalid input', { field: 'email' });

// Throw not found error
throw new NotFoundError('User');
```

## Request Validation

Use Zod schemas with the validation middleware:

```typescript
import { validateRequest } from '../middleware';
import { z } from 'zod';

const schema = z.object({
  body: z.object({
    name: z.string().min(1),
  }),
  query: z.object({
    page: z.string().regex(/^\d+$/).transform(Number),
  }),
});

router.post('/', validateRequest(schema), handler);
```

## Logging

Structured logging with Winston:

```typescript
import { logger } from '../utils/logger';

logger.info('User created', { userId: 123 });
logger.error('Database error', { error, context });
```

## Future Enhancements

- [ ] Database integration (PostgreSQL/MongoDB)
- [ ] Authentication & JWT
- [ ] RBAC implementation
- [ ] Audit logging
- [ ] Workflow engine integration
- [ ] API documentation (OpenAPI/Swagger)
- [ ] Unit and integration tests

