# RBAC Implementation Summary

## ✅ Complete Enterprise RBAC System

### Database Schema (`database/schema.sql`)

**8 Core Tables:**
1. `users` - User accounts with soft delete
2. `roles` - Role definitions (system roles protected)
3. `permissions` - Permission definitions (resource:action format)
4. `user_roles` - Many-to-many user-role assignments
5. `role_permissions` - Many-to-many role-permission assignments
6. `user_permissions` - Direct user permissions (bypass roles, with expiration)
7. `refresh_tokens` - JWT refresh token management
8. `audit_logs` - Audit trail (ready for future use)

**3 Views:**
- `user_role_permissions` - Permissions from roles
- `user_direct_permissions` - Direct user permissions
- `user_all_permissions` - Combined permissions

### Authentication (`src/services/auth.ts`, `src/middleware/auth.ts`)

**Features:**
- ✅ JWT access tokens (15min default)
- ✅ Refresh tokens (7 days, stored in DB)
- ✅ Password hashing with bcrypt
- ✅ Token revocation
- ✅ User authentication middleware
- ✅ Optional authentication middleware

**Endpoints:**
- `POST /api/v1/auth/login` - Login
- `POST /api/v1/auth/register` - Register
- `POST /api/v1/auth/refresh` - Refresh token
- `POST /api/v1/auth/logout` - Logout
- `GET /api/v1/auth/me` - Current user

### RBAC Service (`src/services/rbac.ts`)

**Methods:**
- `hasPermission(userId, permissionName)` - Check single permission
- `hasAnyPermission(userId, permissions[])` - Check any permission
- `hasAllPermissions(userId, permissions[])` - Check all permissions
- `hasResourcePermission(userId, resource, action)` - Resource-based check
- `requirePermission()` - Throw error if no permission
- `getUserPermissions(userId)` - Get all user permissions

### RBAC Middleware (`src/middleware/rbac.ts`)

**Available Middleware:**
1. `requirePermission(permissionName)` - Single permission
2. `requireAnyPermission(...permissions)` - Any of permissions
3. `requireAllPermissions(...permissions)` - All permissions
4. `requireResourcePermission(resource, action)` - Resource-based
5. `requireDynamicPermission(getPermission)` - Dynamic based on request

### Example Routes (`src/routes/rbac-examples.ts`)

Comprehensive examples showing:
- Simple permission checks
- Resource-based permissions
- Multiple permissions (ANY/ALL)
- Dynamic permission checking
- Programmatic permission checks

## Quick Start

### 1. Database Setup

```bash
# Create database
createdb platform_db

# Run schema
psql -U postgres -d platform_db -f database/schema.sql

# Seed data
psql -U postgres -d platform_db -f database/seed.sql
```

### 2. Environment Variables

```env
DATABASE_URL=postgresql://user:password@localhost:5432/platform_db
JWT_SECRET=your-secret-key-minimum-32-characters-long
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
RBAC_ENABLED=true
```

### 3. Create Admin User

```sql
-- Hash password: bcrypt.hashSync('Admin123!', 10)
INSERT INTO users (email, password_hash, first_name, last_name, is_email_verified)
VALUES ('admin@platform.com', '$2a$10$...', 'Admin', 'User', true);

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u, roles r
WHERE u.email = 'admin@platform.com' AND r.name = 'super_admin';
```

### 4. Usage Example

```typescript
import { authenticate, requirePermission } from './middleware';

// Protect route with permission
router.get('/users',
  authenticate,
  requirePermission('users:read'),
  handler
);
```

## Key Features

✅ **No hardcoded roles** - All in database
✅ **Fine-grained permissions** - Resource:action format
✅ **Multiple roles per user**
✅ **Direct permissions** - Bypass roles
✅ **Permission expiration** - Time-limited permissions
✅ **JWT authentication** - Secure token-based
✅ **Refresh tokens** - Long sessions with revocation
✅ **Database-backed** - All checks query database
✅ **Extensible** - Easy to add resources/actions

## File Structure

```
apps/api/
├── database/
│   ├── schema.sql          # Complete database schema
│   ├── seed.sql            # Default roles & permissions
│   └── migrations/         # Migration files
├── src/
│   ├── models/
│   │   ├── database.ts     # DB connection pool
│   │   ├── user.ts          # User model
│   │   ├── role.ts          # Role model
│   │   └── permission.ts    # Permission model
│   ├── services/
│   │   ├── auth.ts          # Authentication service
│   │   └── rbac.ts          # RBAC service
│   ├── middleware/
│   │   ├── auth.ts          # Auth middleware
│   │   └── rbac.ts          # RBAC middleware
│   └── routes/
│       ├── auth.ts          # Auth endpoints
│       └── rbac-examples.ts # RBAC examples
```

## Testing

```bash
# 1. Login
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@platform.com","password":"Admin123!"}'

# 2. Use token
curl -X GET http://localhost:3000/api/v1/examples/users \
  -H "Authorization: Bearer YOUR_TOKEN"

# 3. Check permissions
curl -X GET "http://localhost:3000/api/v1/examples/permissions/check?permission=users:read" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

