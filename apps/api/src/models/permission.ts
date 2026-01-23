import { db } from './database';
import { QueryResult } from 'pg';

/**
 * Permission model types
 */
export interface Permission {
  id: string;
  name: string;
  resource: string;
  action: string;
  description: string | null;
  created_at: Date;
  updated_at: Date;
  deleted_at: Date | null;
}

export interface CreatePermissionInput {
  name: string;
  resource: string;
  action: string;
  description?: string;
}

/**
 * Permission model - Database operations
 */
export class PermissionModel {
  /**
   * Find permission by ID
   */
  static async findById(id: string): Promise<Permission | null> {
    const result: QueryResult<Permission> = await db.query<Permission>(
      `SELECT * FROM permissions 
       WHERE id = $1 AND deleted_at IS NULL`,
      [id]
    );
    return result.rows[0] || null;
  }

  /**
   * Find permission by name
   */
  static async findByName(name: string): Promise<Permission | null> {
    const result: QueryResult<Permission> = await db.query<Permission>(
      `SELECT * FROM permissions 
       WHERE name = $1 AND deleted_at IS NULL`,
      [name]
    );
    return result.rows[0] || null;
  }

  /**
   * List all permissions
   */
  static async findAll(): Promise<Permission[]> {
    const result: QueryResult<Permission> = await db.query<Permission>(
      `SELECT * FROM permissions 
       WHERE deleted_at IS NULL
       ORDER BY resource, action`
    );
    return result.rows;
  }

  /**
   * Find permissions for a user (from roles + direct)
   */
  static async findByUserId(userId: string): Promise<Permission[]> {
    const result: QueryResult<Permission> = await db.query<Permission>(
      `SELECT DISTINCT p.* FROM permissions p
       WHERE p.deleted_at IS NULL
       AND (
         -- Permissions from roles
         p.id IN (
           SELECT rp.permission_id FROM role_permissions rp
           INNER JOIN user_roles ur ON rp.role_id = ur.role_id
           WHERE ur.user_id = $1
         )
         OR
         -- Direct permissions
         p.id IN (
           SELECT up.permission_id FROM user_permissions up
           WHERE up.user_id = $1
           AND (up.expires_at IS NULL OR up.expires_at > CURRENT_TIMESTAMP)
         )
       )
       ORDER BY p.resource, p.action`,
      [userId]
    );
    return result.rows;
  }

  /**
   * Check if user has specific permission
   */
  static async userHasPermission(userId: string, permissionName: string): Promise<boolean> {
    const result = await db.query(
      `SELECT 1 FROM user_all_permissions
       WHERE user_id = $1 AND permission_name = $2
       LIMIT 1`,
      [userId, permissionName]
    );
    return result.rowCount > 0;
  }

  /**
   * Get user permissions as array of permission names
   */
  static async getUserPermissionNames(userId: string): Promise<string[]> {
    const result = await db.query<{ permission_name: string }>(
      `SELECT DISTINCT permission_name FROM user_all_permissions
       WHERE user_id = $1`,
      [userId]
    );
    return result.rows.map((row) => row.permission_name);
  }
}


