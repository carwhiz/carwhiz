// filepath: src/lib/services/permissionService.ts
import { supabase } from '../supabaseClient';

export interface UserPermission {
  id: string;
  user_id: string;
  resource: string;
  can_view: boolean;
  can_create: boolean;
  can_edit: boolean;
  can_delete: boolean;
}

/**
 * Cache for user permissions to avoid repeated queries
 * Key: userId, Value: Map of resource -> permission
 * 
 * NOTE: Cache duration is SHORT (10 seconds) to ensure permission changes
 * are reflected quickly when admins revoke/grant permissions
 */
const permissionCache = new Map<string, Map<string, UserPermission>>();
const CACHE_DURATION = 10 * 1000; // Only 10 seconds - permissions change frequently
const cacheTimestamps = new Map<string, number>();

/**
 * Load user permissions from Supabase
 * Results are cached to minimize database queries
 */
export async function loadUserPermissions(userId: string): Promise<Map<string, UserPermission>> {
  // Check cache validity
  const cachedPerms = permissionCache.get(userId);
  const cacheTime = cacheTimestamps.get(userId);
  if (cachedPerms && cacheTime && Date.now() - cacheTime < CACHE_DURATION) {
    console.log(`[Permission] Cache HIT for user ${userId}, cached permissions:`, Array.from(cachedPerms.entries()));
    return cachedPerms;
  }

  console.log(`[Permission] Cache MISS for user ${userId}, fetching from DB...`);

  // Fetch from database
  const { data, error } = await supabase
    .from('permissions')
    .select('*')
    .eq('user_id', userId);

  if (error) {
    console.error('Error loading permissions:', error);
    return new Map();
  }

  console.log(`[Permission] DB Query result for user ${userId}:`, data);

  // Build permission map
  const permMap = new Map<string, UserPermission>();
  (data as UserPermission[]).forEach(perm => {
    permMap.set(perm.resource, perm);
  });

  // Cache results
  permissionCache.set(userId, permMap);
  cacheTimestamps.set(userId, Date.now());

  console.log(`[Permission] Built permission map for user ${userId}:`, Array.from(permMap.entries()));

  return permMap;
}

/**
 * Check if user can view a specific resource
 * @param userId - User ID
 * @param resourceId - Resource ID (e.g., 'mobile-dashboard-sales')
 * @returns true if user can view, false otherwise
 */
export async function canUserViewResource(userId: string, resourceId: string): Promise<boolean> {
  const permissions = await loadUserPermissions(userId);
  const perm = permissions.get(resourceId);
  const result = perm?.can_view ?? false;
  
  console.log(`[Permission CHECK] User: ${userId}, Resource: ${resourceId}`, {
    permissionExists: !!perm,
    permissionRecord: perm || 'NO RECORD',
    can_view: perm?.can_view,
    finalResult: result,
    accessAllowed: result ? 'ALLOWED' : 'DENIED'
  });
  
  return result;
}

/**
 * Check if user can create in a specific resource
 */
export async function canUserCreateResource(userId: string, resourceId: string): Promise<boolean> {
  const permissions = await loadUserPermissions(userId);
  const perm = permissions.get(resourceId);
  const result = perm?.can_create ?? false;
  
  console.log(`[Permission CREATE CHECK] User: ${userId}, Resource: ${resourceId}`, {
    permissionExists: !!perm,
    permissionRecord: perm || 'NO RECORD',
    can_create: perm?.can_create,
    finalResult: result,
    accessAllowed: result ? 'ALLOWED' : 'DENIED'
  });
  
  return result;
}

/**
 * Check if user can edit in a specific resource
 */
export async function canUserEditResource(userId: string, resourceId: string): Promise<boolean> {
  const permissions = await loadUserPermissions(userId);
  const perm = permissions.get(resourceId);
  return perm?.can_edit ?? false;
}

/**
 * Check if user can delete in a specific resource
 */
export async function canUserDeleteResource(userId: string, resourceId: string): Promise<boolean> {
  const permissions = await loadUserPermissions(userId);
  const perm = permissions.get(resourceId);
  return perm?.can_delete ?? false;
}

/**
 * Check multiple permissions at once
 * @param userId - User ID
 * @param resourceIds - Array of resource IDs to check
 * @returns Map of resourceId -> can_view boolean
 */
export async function canUserViewResources(userId: string, resourceIds: string[]): Promise<Map<string, boolean>> {
  const permissions = await loadUserPermissions(userId);
  const result = new Map<string, boolean>();

  for (const resourceId of resourceIds) {
    const perm = permissions.get(resourceId);
    result.set(resourceId, perm?.can_view ?? false);
  }

  return result;
}

/**
 * Clear permission cache for a user (call after permission changes)
 */
export function clearUserPermissionCache(userId: string): void {
  permissionCache.delete(userId);
  cacheTimestamps.delete(userId);
}

/**
 * Clear all permission caches
 */
export function clearAllPermissionCaches(): void {
  permissionCache.clear();
  cacheTimestamps.clear();
}
