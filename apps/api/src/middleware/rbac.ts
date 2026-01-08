import { Request, Response, NextFunction } from 'express';
import { RBACService } from '../services/rbac';
import { AuthorizationError, AuthenticationError } from '../utils/errors';
import { asyncHandler } from './validator';

/**
 * RBAC Middleware Factory
 * Creates middleware to check permissions
 */

/**
 * Require a specific permission
 */
export function requirePermission(permissionName: string) {
  return asyncHandler(
    async (req: Request, res: Response, next: NextFunction): Promise<void> => {
      if (!req.user) {
        throw new AuthenticationError('Authentication required');
      }

      await RBACService.requirePermission(req.user.id, permissionName);
      next();
    }
  );
}

/**
 * Require any of the specified permissions
 */
export function requireAnyPermission(...permissionNames: string[]) {
  return asyncHandler(
    async (req: Request, res: Response, next: NextFunction): Promise<void> => {
      if (!req.user) {
        throw new AuthenticationError('Authentication required');
      }

      await RBACService.requireAnyPermission(req.user.id, permissionNames);
      next();
    }
  );
}

/**
 * Require all of the specified permissions
 */
export function requireAllPermissions(...permissionNames: string[]) {
  return asyncHandler(
    async (req: Request, res: Response, next: NextFunction): Promise<void> => {
      if (!req.user) {
        throw new AuthenticationError('Authentication required');
      }

      await RBACService.requireAllPermissions(req.user.id, permissionNames);
      next();
    }
  );
}

/**
 * Require permission for a resource and action
 * Example: requireResourcePermission('users', 'create')
 */
export function requireResourcePermission(resource: string, action: string) {
  return asyncHandler(
    async (req: Request, res: Response, next: NextFunction): Promise<void> => {
      if (!req.user) {
        throw new AuthenticationError('Authentication required');
      }

      await RBACService.requireResourcePermission(req.user.id, resource, action);
      next();
    }
  );
}

/**
 * Dynamic permission checker
 * Allows checking permissions based on request parameters
 * 
 * @example
 * requireDynamicPermission((req) => `users:${req.params.action}`)
 */
export function requireDynamicPermission(
  getPermission: (req: Request) => string | string[]
) {
  return asyncHandler(
    async (req: Request, res: Response, next: NextFunction): Promise<void> => {
      if (!req.user) {
        throw new AuthenticationError('Authentication required');
      }

      const permission = getPermission(req);
      
      if (Array.isArray(permission)) {
        await RBACService.requireAnyPermission(req.user.id, permission);
      } else {
        await RBACService.requirePermission(req.user.id, permission);
      }

      next();
    }
  );
}

