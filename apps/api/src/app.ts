import express, { Express } from 'express';
import 'express-async-errors'; // Must be imported before routes
import { config } from './config';
import { logger } from './utils/logger';
import { db } from './models/database';
import { redisClient } from './services/redis';
import {
  securityMiddleware,
  requestId,
  requestLogger,
  errorHandler,
  notFoundHandler,
} from './middleware';
import apiRouter from './routes';

/**
 * Application factory function
 * Creates and configures Express application
 * Separated for easier testing and modularity
 */
export function createApp(): Express {
  // Initialize database connection
  db.initialize();

  // Initialize Redis connection
  redisClient.initialize();

  const app = express();

  // Trust proxy (for rate limiting behind reverse proxy)
  app.set('trust proxy', 1);

  // Security middleware (helmet, CORS, compression, rate limiting)
  app.use(securityMiddleware());

  // Request ID middleware (for tracing)
  app.use(requestId);

  // Request logging middleware
  app.use(requestLogger);

  // Body parsing middleware
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // API routes
  app.use(`/api/${config.app.apiVersion}`, apiRouter);

  // Root endpoint
  app.get('/', (req, res) => {
    res.json({
      success: true,
      message: 'Legal & Real Estate Platform API',
      version: config.app.apiVersion,
      documentation: `/api/${config.app.apiVersion}`,
    });
  });

  // 404 handler (must be before error handler)
  app.use(notFoundHandler);

  // Global error handler (must be last)
  app.use(errorHandler);

  return app;
}

/**
 * Start server function
 * Separated for easier testing
 */
export function startServer(): void {
  const app = createApp();

  const server = app.listen(config.app.port, () => {
    logger.info('Server started', {
      port: config.app.port,
      environment: config.app.env,
      apiVersion: config.app.apiVersion,
    });
  });

  // Graceful shutdown
  const gracefulShutdown = async (signal: string) => {
    logger.info(`${signal} received, shutting down gracefully`);
    server.close(async () => {
      logger.info('HTTP server closed');
      await db.close();
      await redisClient.close();
      logger.info('Process terminated');
      process.exit(0);
    });
  };

  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
}

