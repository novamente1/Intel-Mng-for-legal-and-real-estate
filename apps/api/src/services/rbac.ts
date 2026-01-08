import { PermissionModel } from '../models/permission';
import { AuthorizationError } from '../utils/errors';
import { logger } from '../utils/logger';

/**
 * RBAC Service
 * Handles permission checking and role management
 */
export class RBACService {
  /**
   * Check if user has a specific permission
   */
  static async hasPermission(userId: string, permissionName: string): Promise<boolean> {
    return PermissionModel.userHasPermission(userId, permissionName);
  }

  /**
   * Check if user has any of the specified permissions
   */
  static async hasAnyPermission(userId: string, permissionNames: string[]): Promise<boolean> {
    const userPermissions = await PermissionModel.getUserPermissionNames(userId);
    return permissionNames.some((perm) => userPermissions.includes(perm));
  }

  /**
   * Check if user has all of the specified permissions
   */
  static async hasAllPermissions(userId: string, permissionNames: string[]): Promise<boolean> {
    const userPermissions = await PermissionModel.getUserPermissionNames(userId);
    return permissionNames.every((perm) => userPermissions.includes(perm));
  }

  /**
   * Check if user has permission for a specific resource and action
   */
  static async hasResourcePermission(
    userId: string,
    resource: string,
    action: string
  ): Promise<boolean> {
    const permissionName = `${resource}:${action}`;
    return this.hasPermission(userId, permissionName);
  }

  /**
   * Get all permissions for a user
   */
  static async getUserPermissions(userId: string): Promise<string[]> {
    return PermissionModel.getUserPermissionNames(userId);
  }

  /**
   * Require permission - throws error if user doesn't have permission
   */
  static async requirePermission(userId: string, permissionName: string): Promise<void> {
    const hasPermission = await this.hasPermission(userId, permissionName);

    if (!hasPermission) {
      logger.warn('Permission denied', { userId, permissionName });
      throw new AuthorizationError(
        `Insufficient permissions. Required: ${permissionName}`
      );
    }
  }

  /**
   * Require any of the specified permissions
   */
  static async requireAnyPermission(
    userId: string,
    permissionNames: string[]
  ): Promise<void> {
    const hasAny = await this.hasAnyPermission(userId, permissionNames);

    if (!hasAny) {
      logger.warn('Permission denied', { userId, requiredPermissions: permissionNames });
      throw new AuthorizationError(
        `Insufficient permissions. Required one of: ${permissionNames.join(', ')}`
      );
    }
  }

  /**
   * Require all of the specified permissions
   */
  static async requireAllPermissions(
    userId: string,
    permissionNames: string[]
  ): Promise<void> {
    const hasAll = await this.hasAllPermissions(userId, permissionNames);

    if (!hasAll) {
      logger.warn('Permission denied', { userId, requiredPermissions: permissionNames });
      throw new AuthorizationError(
        `Insufficient permissions. Required all of: ${permissionNames.join(', ')}`
      );
    }
  }

  /**
   * Require resource permission
   */
  static async requireResourcePermission(
    userId: string,
    resource: string,
    action: string
  ): Promise<void> {
    const permissionName = `${resource}:${action}`;
    await this.requirePermission(userId, permissionName);
  }
}

