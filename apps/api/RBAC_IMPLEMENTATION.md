# Enterprise RBAC Implementation

## Overview

Complete Role-Based Access Control (RBAC) system with JWT authentication, fine-grained permissions, and PostgreSQL storage.

## Database Schema

### Core Tables

1. **users** - User accounts
   - Stores user credentials and profile information
   - Soft delete support

2. **roles** - Role definitions
   - System roles cannot be deleted
   - Flexible role management

3. **permissions** - Permission definitions
   - Format: `resource:action` (e.g., `users:create`, `documents:read`)
   - Supports fine-grained access control

4. **user_roles** - User-Role assignments (Many-to-Many)
   - Users can have multiple roles
   - Tracks who assigned the role

5. **role_permissions** - Role-Permission assignments (Many-to-Many)
   - Roles can have multiple permissions
   - Tracks who granted the permission

6. **user_permissions** - Direct user permissions (optional)
   - Allows bypassing roles for specific permissions
   - Supports expiration dates

7. **refresh_tokens** - JWT refresh token management
   - Token revocation support
   - Tracks user agent and IP

8. **audit_logs** - Audit trail (for future use)
   - Tracks all user actions
   - JSONB for flexible details

### Views

- **user_role_permissions** - Permissions from roles
- **user_direct_permissions** - Direct user permissions
- **user_all_permissions** - Combined permissions (roles + direct)

## Authentication

### JWT Tokens

- **Access Token**: Short-lived (15 minutes default)
- **Refresh Token**: Long-lived (7 days default), stored in database

### Endpoints

- `POST /api/v1/auth/login` - Authenticate and get tokens
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/refresh` - Refresh access token
- `POST /api/v1/auth/logout` - Revoke refresh token
- `GET /api/v1/auth/me` - Get current user

## RBAC Middleware

### Available Middleware

1. **`authenticate`** - Verify JWT and attach user to request
2. **`requirePermission(permissionName)`** - Require specific permission
3. **`requireAnyPermission(...permissions)`** - Require any of the permissions
4. **`requireAllPermissions(...permissions)`** - Require all permissions
5. **`requireResourcePermission(resource, action)`** - Resource-based check
6. **`requireDynamicPermission(getPermission)`** - Dynamic permission based on request

### Usage Examples

```typescript
// Simple permission check
router.get('/users', 
  authenticate, 
  requirePermission('users:read'),
  handler
);

// Resource-based permission
router.post('/documents',
  authenticate,
  requireResourcePermission('documents', 'create'),
  handler
);

// Multiple permissions (ANY)
router.get('/reports',
  authenticate,
  requireAnyPermission('reports:read', 'reports:generate'),
  handler
);

// Multiple permissions (ALL)
router.post('/reports/export',
  authenticate,
  requireAllPermissions('reports:read', 'reports:export'),
  handler
);

// Dynamic permission
router.get('/:resource/:action',
  authenticate,
  requireDynamicPermission((req) => `${req.params.resource}:${req.params.action}`),
  handler
);
```

## Permission Naming Convention

Format: `resource:action`

Examples:
- `users:create` - Create users
- `users:read` - Read users
- `users:update` - Update users
- `users:delete` - Delete users
- `documents:read` - Read documents
- `reports:export` - Export reports

## Default Roles & Permissions

### Super Admin
- All permissions

### Admin
- User management (`users:*`)
- Role management (`roles:*`)
- Permission management (`permissions:*`)
- Audit read (`audit:read`)

### Manager
- Document management (`documents:*`)
- Report access (`reports:*`)

### User
- Basic read permissions (`documents:read`, `reports:read`)

## Environment Variables

```env
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/dbname

# JWT
JWT_SECRET=your-secret-key-min-32-characters-long
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# RBAC
RBAC_ENABLED=true
```

## Setup Instructions

1. **Create database and run schema:**
   ```bash
   psql -U postgres -d your_database -f database/schema.sql
   ```

2. **Seed initial data:**
   ```bash
   psql -U postgres -d your_database -f database/seed.sql
   ```

3. **Create admin user (use bcrypt to hash password):**
   ```sql
   INSERT INTO users (email, password_hash, first_name, last_name, is_email_verified)
   VALUES ('admin@platform.com', '$2a$10$...', 'Admin', 'User', true);
   
   INSERT INTO user_roles (user_id, role_id)
   SELECT u.id, r.id FROM users u, roles r
   WHERE u.email = 'admin@platform.com' AND r.name = 'super_admin';
   ```

4. **Update environment variables** in `.env`

5. **Start the server:**
   ```bash
   npm run dev
   ```

## Testing RBAC

### Example Test Flow

1. **Register/Login:**
   ```bash
   curl -X POST http://localhost:3000/api/v1/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"admin@platform.com","password":"Admin123!"}'
   ```

2. **Access protected route:**
   ```bash
   curl -X GET http://localhost:3000/api/v1/examples/users \
     -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
   ```

3. **Check permissions:**
   ```bash
   curl -X GET "http://localhost:3000/api/v1/examples/permissions/check?permission=users:read" \
     -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
   ```

## Key Features

✅ **No hardcoded roles** - All roles stored in database
✅ **Fine-grained permissions** - Resource:action format
✅ **Multiple roles per user** - Users can have multiple roles
✅ **Direct permissions** - Bypass roles when needed
✅ **Permission expiration** - Direct permissions can expire
✅ **JWT-based auth** - Secure token-based authentication
✅ **Refresh tokens** - Long-lived sessions with revocation
✅ **Audit ready** - Database schema supports audit logging
✅ **Extensible** - Easy to add new resources and actions

## Security Considerations

- Passwords are hashed using bcrypt (10 rounds)
- JWT tokens are signed with secret key
- Refresh tokens are stored in database and can be revoked
- Soft deletes preserve data integrity
- System roles cannot be deleted
- All permission checks are database-backed

