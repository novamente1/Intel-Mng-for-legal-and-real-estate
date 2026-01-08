-- Seed data for RBAC system
-- Initial roles, permissions, and admin user

-- ============================================
-- DEFAULT PERMISSIONS
-- ============================================

-- User management permissions
INSERT INTO permissions (name, resource, action, description) VALUES
('users:create', 'users', 'create', 'Create new users'),
('users:read', 'users', 'read', 'View users'),
('users:update', 'users', 'update', 'Update user information'),
('users:delete', 'users', 'delete', 'Delete users'),
('users:list', 'users', 'list', 'List all users'),
('users:assign-role', 'users', 'assign-role', 'Assign roles to users')
ON CONFLICT (name) DO NOTHING;

-- Role management permissions
INSERT INTO permissions (name, resource, action, description) VALUES
('roles:create', 'roles', 'create', 'Create new roles'),
('roles:read', 'roles', 'read', 'View roles'),
('roles:update', 'roles', 'update', 'Update role information'),
('roles:delete', 'roles', 'delete', 'Delete roles'),
('roles:list', 'roles', 'list', 'List all roles'),
('roles:assign-permission', 'roles', 'assign-permission', 'Assign permissions to roles')
ON CONFLICT (name) DO NOTHING;

-- Permission management permissions
INSERT INTO permissions (name, resource, action, description) VALUES
('permissions:create', 'permissions', 'create', 'Create new permissions'),
('permissions:read', 'permissions', 'read', 'View permissions'),
('permissions:list', 'permissions', 'list', 'List all permissions')
ON CONFLICT (name) DO NOTHING;

-- Document management permissions (example)
INSERT INTO permissions (name, resource, action, description) VALUES
('documents:create', 'documents', 'create', 'Create documents'),
('documents:read', 'documents', 'read', 'View documents'),
('documents:update', 'documents', 'update', 'Update documents'),
('documents:delete', 'documents', 'delete', 'Delete documents'),
('documents:list', 'documents', 'list', 'List documents'),
('documents:export', 'documents', 'export', 'Export documents')
ON CONFLICT (name) DO NOTHING;

-- Report permissions (example)
INSERT INTO permissions (name, resource, action, description) VALUES
('reports:read', 'reports', 'read', 'View reports'),
('reports:generate', 'reports', 'generate', 'Generate reports'),
('reports:export', 'reports', 'export', 'Export reports')
ON CONFLICT (name) DO NOTHING;

-- Audit log permissions
INSERT INTO permissions (name, resource, action, description) VALUES
('audit:read', 'audit', 'read', 'View audit logs'),
('audit:list', 'audit', 'list', 'List audit logs')
ON CONFLICT (name) DO NOTHING;

-- ============================================
-- DEFAULT ROLES
-- ============================================

-- Super Admin Role (has all permissions)
INSERT INTO roles (name, description, is_system_role) VALUES
('super_admin', 'Super Administrator with all permissions', true)
ON CONFLICT (name) DO NOTHING;

-- Admin Role
INSERT INTO roles (name, description, is_system_role) VALUES
('admin', 'Administrator with management permissions', false)
ON CONFLICT (name) DO NOTHING;

-- Manager Role
INSERT INTO roles (name, description, is_system_role) VALUES
('manager', 'Manager with document and report access', false)
ON CONFLICT (name) DO NOTHING;

-- User Role (basic user)
INSERT INTO roles (name, description, is_system_role) VALUES
('user', 'Standard user with basic permissions', false)
ON CONFLICT (name) DO NOTHING;

-- ============================================
-- ROLE PERMISSIONS
-- ============================================

-- Super Admin gets all permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'super_admin'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Admin gets user, role, and permission management
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'admin'
    AND (p.resource IN ('users', 'roles', 'permissions') OR p.name = 'audit:read')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Manager gets document and report permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'manager'
    AND p.resource IN ('documents', 'reports')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- User gets basic read permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'user'
    AND p.action = 'read'
    AND p.resource IN ('documents', 'reports')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- ============================================
-- DEFAULT ADMIN USER
-- Password: Admin123! (change in production)
-- Use bcrypt to hash: bcrypt.hashSync('Admin123!', 10)
-- ============================================
-- Note: Replace the password hash below with a properly hashed password
-- Example hash for 'Admin123!': $2a$10$rOzJqZqZqZqZqZqZqZqZqOqZqZqZqZqZqZqZqZqZqZqZqZqZqZq
-- INSERT INTO users (email, password_hash, first_name, last_name, is_email_verified)
-- VALUES ('admin@platform.com', '$2a$10$rOzJqZqZqZqZqZqZqZqZqOqZqZqZqZqZqZqZqZqZqZqZqZqZqZq', 'Admin', 'User', true)
-- ON CONFLICT (email) DO NOTHING;

-- Assign super_admin role to admin user (uncomment after creating user)
-- INSERT INTO user_roles (user_id, role_id)
-- SELECT u.id, r.id
-- FROM users u
-- CROSS JOIN roles r
-- WHERE u.email = 'admin@platform.com' AND r.name = 'super_admin'
-- ON CONFLICT (user_id, role_id) DO NOTHING;

