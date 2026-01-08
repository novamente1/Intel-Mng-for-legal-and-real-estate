import { Router, Request, Response } from 'express';
import { asyncHandler } from '../middleware';
import { config } from '../config';

const router = Router();

/**
 * Health check endpoint
 * Returns API status and system information
 * 
 * GET /health
 */
router.get(
  '/',
  asyncHandler(async (req: Request, res: Response) => {
    const healthData = {
      success: true,
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: config.app.env,
      version: config.app.apiVersion,
      service: 'api',
      // Future: Add database connectivity check
      // database: await checkDatabaseConnection(),
      // Future: Add external service health checks
      // services: {
      //   intelligence: await checkIntelligenceService(),
      // },
    };

    res.status(200).json(healthData);
  })
);

/**
 * Readiness probe endpoint
 * Used by Kubernetes to check if service is ready to accept traffic
 * 
 * GET /health/ready
 */
router.get(
  '/ready',
  asyncHandler(async (req: Request, res: Response) => {
    // Add readiness checks here (database, external services, etc.)
    const isReady = true; // Placeholder

    if (isReady) {
      res.status(200).json({
        success: true,
        status: 'ready',
        timestamp: new Date().toISOString(),
      });
    } else {
      res.status(503).json({
        success: false,
        status: 'not ready',
        timestamp: new Date().toISOString(),
      });
    }
  })
);

/**
 * Liveness probe endpoint
 * Used by Kubernetes to check if service is alive
 * 
 * GET /health/live
 */
router.get(
  '/live',
  asyncHandler(async (req: Request, res: Response) => {
    res.status(200).json({
      success: true,
      status: 'alive',
      timestamp: new Date().toISOString(),
    });
  })
);

export default router;

