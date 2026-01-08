import { Pool, PoolClient, QueryResult } from 'pg';
import { config } from '../config';
import { logger } from '../utils/logger';

/**
 * Database connection pool
 * Singleton pattern for connection management
 */
class Database {
  private pool: Pool | null = null;

  /**
   * Initialize database connection pool
   */
  initialize(): void {
    if (this.pool) {
      logger.warn('Database pool already initialized');
      return;
    }

    this.pool = new Pool({
      connectionString: config.database.url,
      max: 20, // Maximum number of clients in the pool
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
    });

    // Handle pool errors
    this.pool.on('error', (err) => {
      logger.error('Unexpected database pool error', { error: err });
    });

    logger.info('Database connection pool initialized');
  }

  /**
   * Get database connection pool
   */
  getPool(): Pool {
    if (!this.pool) {
      throw new Error('Database pool not initialized. Call initialize() first.');
    }
    return this.pool;
  }

  /**
   * Execute a query
   */
  async query<T = unknown>(
    text: string,
    params?: unknown[]
  ): Promise<QueryResult<T>> {
    const pool = this.getPool();
    const start = Date.now();
    
    try {
      const result = await pool.query<T>(text, params);
      const duration = Date.now() - start;
      
      logger.debug('Database query executed', {
        query: text.substring(0, 100),
        duration: `${duration}ms`,
        rows: result.rowCount,
      });
      
      return result;
    } catch (error) {
      const duration = Date.now() - start;
      logger.error('Database query error', {
        query: text.substring(0, 100),
        duration: `${duration}ms`,
        error,
      });
      throw error;
    }
  }

  /**
   * Get a client from the pool for transactions
   */
  async getClient(): Promise<PoolClient> {
    const pool = this.getPool();
    return pool.connect();
  }

  /**
   * Close all database connections
   */
  async close(): Promise<void> {
    if (this.pool) {
      await this.pool.end();
      this.pool = null;
      logger.info('Database connection pool closed');
    }
  }

  /**
   * Test database connection
   */
  async testConnection(): Promise<boolean> {
    try {
      await this.query('SELECT NOW()');
      return true;
    } catch (error) {
      logger.error('Database connection test failed', { error });
      return false;
    }
  }
}

// Export singleton instance
export const db = new Database();

