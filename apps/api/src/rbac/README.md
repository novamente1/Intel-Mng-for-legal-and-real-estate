# RBAC Module

This directory contains the Role-Based Access Control implementation.

## Components

### Services
- `../services/rbac.ts` - RBAC service for permission checking
- `../services/auth.ts` - Authentication service for JWT and password management

### Middleware
- `../middleware/auth.ts` - Authentication middleware (JWT verification)
- `../middleware/rbac.ts` - RBAC middleware for route protection

### Models
- `../models/user.ts` - User model
- `../models/role.ts` - Role model
- `../models/permission.ts` - Permission model

### Database
- `../database/schema.sql` - Complete database schema
- `../database/seed.sql` - Seed data with default roles and permissions

## Usage Examples

See `../routes/rbac-examples.ts` for comprehensive examples of:
- Simple permission checks
- Resource-based permissions
- Multiple permission requirements (ANY/ALL)
- Dynamic permission checking
- Programmatic permission checks
