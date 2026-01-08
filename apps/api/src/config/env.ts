import { z } from 'zod';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

/**
 * Environment variable schema validation
 * Ensures all required environment variables are present and valid
 */
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().regex(/^\d+$/).transform(Number).default('3000'),
  API_VERSION: z.string().default('v1'),
  LOG_LEVEL: z.enum(['error', 'warn', 'info', 'debug']).default('info'),
  
  // Security
  CORS_ORIGIN: z.string().default('*'),
  RATE_LIMIT_WINDOW_MS: z.string().regex(/^\d+$/).transform(Number).default('900000'), // 15 minutes
  RATE_LIMIT_MAX_REQUESTS: z.string().regex(/^\d+$/).transform(Number).default('100'),
  
  // Future: Database, RBAC, Audit
  // DATABASE_URL: z.string().url().optional(),
  // JWT_SECRET: z.string().min(32).optional(),
  // AUDIT_LOG_LEVEL: z.enum(['minimal', 'standard', 'verbose']).optional(),
});

type EnvConfig = z.infer<typeof envSchema>;

/**
 * Validates and returns environment configuration
 * Throws error if validation fails
 */
function validateEnv(): EnvConfig {
  try {
    return envSchema.parse(process.env);
  } catch (error) {
    if (error instanceof z.ZodError) {
      const missingVars = error.errors.map((err) => `${err.path.join('.')}: ${err.message}`);
      throw new Error(
        `Invalid environment configuration:\n${missingVars.join('\n')}`
      );
    }
    throw error;
  }
}

export const env = validateEnv();

/**
 * Type-safe environment configuration
 */
export const config = {
  app: {
    env: env.NODE_ENV,
    port: env.PORT,
    apiVersion: env.API_VERSION,
    isDevelopment: env.NODE_ENV === 'development',
    isProduction: env.NODE_ENV === 'production',
    isTest: env.NODE_ENV === 'test',
  },
  security: {
    corsOrigin: env.CORS_ORIGIN,
    rateLimit: {
      windowMs: env.RATE_LIMIT_WINDOW_MS,
      maxRequests: env.RATE_LIMIT_MAX_REQUESTS,
    },
  },
  logging: {
    level: env.LOG_LEVEL,
  },
  // Placeholders for future configuration
  // database: {
  //   url: env.DATABASE_URL,
  // },
  // rbac: {
  //   // RBAC configuration
  // },
  // audit: {
  //   logLevel: env.AUDIT_LOG_LEVEL,
  // },
} as const;

