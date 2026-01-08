import { Router } from 'express';
import healthRouter from './health';
import { config } from '../config';

const router = Router();

/**
 * API routes registration
 * All routes are prefixed with /api/{version}
 */

// Health check routes
router.use('/health', healthRouter);

// Future: Add more route modules here
// router.use('/users', userRouter);
// router.use('/auth', authRouter);
// router.use('/rbac', rbacRouter);
// router.use('/audit', auditRouter);

/**
 * API info endpoint
 * GET /api/v1
 */
router.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'API is running',
    version: config.app.apiVersion,
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/api/v1/health',
      // Future: Add more endpoints as they're created
    },
  });
});

export default router;

