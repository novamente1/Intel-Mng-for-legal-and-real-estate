import { db } from './database';
import { QueryResult } from 'pg';

/**
 * User model types
 */
export interface User {
  id: string;
  email: string;
  password_hash: string;
  first_name: string | null;
  last_name: string | null;
  is_active: boolean;
  is_email_verified: boolean;
  last_login_at: Date | null;
  created_at: Date;
  updated_at: Date;
  deleted_at: Date | null;
}

export interface CreateUserInput {
  email: string;
  password_hash: string;
  first_name?: string;
  last_name?: string;
}

export interface UpdateUserInput {
  first_name?: string;
  last_name?: string;
  is_active?: boolean;
  is_email_verified?: boolean;
}

/**
 * User model - Database operations
 */
export class UserModel {
  /**
   * Find user by ID
   */
  static async findById(id: string): Promise<User | null> {
    const result: QueryResult<User> = await db.query<User>(
      `SELECT * FROM users 
       WHERE id = $1 AND deleted_at IS NULL`,
      [id]
    );
    return result.rows[0] || null;
  }

  /**
   * Find user by email
   */
  static async findByEmail(email: string): Promise<User | null> {
    const result: QueryResult<User> = await db.query<User>(
      `SELECT * FROM users 
       WHERE email = $1 AND deleted_at IS NULL`,
      [email]
    );
    return result.rows[0] || null;
  }

  /**
   * Create new user
   */
  static async create(input: CreateUserInput): Promise<User> {
    const result: QueryResult<User> = await db.query<User>(
      `INSERT INTO users (email, password_hash, first_name, last_name)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [input.email, input.password_hash, input.first_name || null, input.last_name || null]
    );
    return result.rows[0];
  }

  /**
   * Update user
   */
  static async update(id: string, input: UpdateUserInput): Promise<User | null> {
    const fields: string[] = [];
    const values: unknown[] = [];
    let paramIndex = 1;

    if (input.first_name !== undefined) {
      fields.push(`first_name = $${paramIndex++}`);
      values.push(input.first_name);
    }
    if (input.last_name !== undefined) {
      fields.push(`last_name = $${paramIndex++}`);
      values.push(input.last_name);
    }
    if (input.is_active !== undefined) {
      fields.push(`is_active = $${paramIndex++}`);
      values.push(input.is_active);
    }
    if (input.is_email_verified !== undefined) {
      fields.push(`is_email_verified = $${paramIndex++}`);
      values.push(input.is_email_verified);
    }

    if (fields.length === 0) {
      return this.findById(id);
    }

    values.push(id);
    const result: QueryResult<User> = await db.query<User>(
      `UPDATE users 
       SET ${fields.join(', ')}
       WHERE id = $${paramIndex} AND deleted_at IS NULL
       RETURNING *`,
      values
    );
    return result.rows[0] || null;
  }

  /**
   * Update last login timestamp
   */
  static async updateLastLogin(id: string): Promise<void> {
    await db.query(
      `UPDATE users 
       SET last_login_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [id]
    );
  }

  /**
   * Soft delete user
   */
  static async delete(id: string): Promise<boolean> {
    const result = await db.query(
      `UPDATE users 
       SET deleted_at = CURRENT_TIMESTAMP
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING id`,
      [id]
    );
    return result.rowCount > 0;
  }
}

