import { db } from './database';
import { QueryResult } from 'pg';

/**
 * Role model types
 */
export interface Role {
  id: string;
  name: string;
  description: string | null;
  is_system_role: boolean;
  created_at: Date;
  updated_at: Date;
  deleted_at: Date | null;
}

export interface CreateRoleInput {
  name: string;
  description?: string;
  is_system_role?: boolean;
}

/**
 * Role model - Database operations
 */
export class RoleModel {
  /**
   * Find role by ID
   */
  static async findById(id: string): Promise<Role | null> {
    const result: QueryResult<Role> = await db.query<Role>(
      `SELECT * FROM roles 
       WHERE id = $1 AND deleted_at IS NULL`,
      [id]
    );
    return result.rows[0] || null;
  }

  /**
   * Find role by name
   */
  static async findByName(name: string): Promise<Role | null> {
    const result: QueryResult<Role> = await db.query<Role>(
      `SELECT * FROM roles 
       WHERE name = $1 AND deleted_at IS NULL`,
      [name]
    );
    return result.rows[0] || null;
  }

  /**
   * List all roles
   */
  static async findAll(): Promise<Role[]> {
    const result: QueryResult<Role> = await db.query<Role>(
      `SELECT * FROM roles 
       WHERE deleted_at IS NULL
       ORDER BY name`
    );
    return result.rows;
  }

  /**
   * Find roles for a user
   */
  static async findByUserId(userId: string): Promise<Role[]> {
    const result: QueryResult<Role> = await db.query<Role>(
      `SELECT r.* FROM roles r
       INNER JOIN user_roles ur ON r.id = ur.role_id
       WHERE ur.user_id = $1 AND r.deleted_at IS NULL
       ORDER BY r.name`,
      [userId]
    );
    return result.rows;
  }
}


