import { supabase } from '../supabaseClient';
import type { LoginPayload, User } from '../../types/auth';
import { authStore } from '../../stores/authStore';

const STORAGE_KEY = 'carwhizz_user';

// Validate 6-digit password/code
export function validatePassword(password: string): boolean {
  const passwordRegex = /^\d{6}$/;
  return passwordRegex.test(password);
}

// Login user via access code
export async function login(payload: LoginPayload): Promise<{ success: boolean; error?: string }> {
  try {
    authStore.setLoading(true);
    authStore.setError(null);

    // Validate inputs
    if (!validatePassword(payload.password)) {
      throw new Error('Access code must be exactly 6 digits');
    }

    // Start login timing for performance monitoring
    const startTime = performance.now();

    // Authenticate via access code RPC function with timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15000); // 15s timeout

    const { data, error } = await supabase.rpc('authenticate_by_code', {
      p_password: payload.password,
    });

    clearTimeout(timeoutId);

    if (error) {
      throw error;
    }

    if (data?.error) {
      throw new Error(data.error);
    }

    const user: User = {
      id: data.id,
      email: data.email,
      phone_number: data.phone_number,
      role: data.role,
      created_at: data.created_at,
    };

    // Persist session in localStorage (fast, synchronous)
    localStorage.setItem(STORAGE_KEY, JSON.stringify(user));
    
    // Update auth store (triggers UI updates)
    authStore.setUser(user);
    authStore.setLoading(false);

    // Log performance metric (non-blocking)
    const endTime = performance.now();
    const duration = endTime - startTime;
    if (duration > 2000) {
      console.warn(`⚠️ Login took ${duration.toFixed(0)}ms - check database performance`);
    } else {
      console.log(`✓ Login completed in ${duration.toFixed(0)}ms`);
    }

    // Update last login timestamp asynchronously (doesn't block UI)
    updateLastLoginAsync(user.id).catch(err => 
      console.warn('Failed to update last login:', err)
    );

    return { success: true };
  } catch (error: any) {
    const errorMessage = error?.message || 'Login failed';
    authStore.setError(errorMessage);
    authStore.setLoading(false);
    return { success: false, error: errorMessage };
  }
}

// Update user's last login timestamp asynchronously
async function updateLastLoginAsync(userId: string): Promise<void> {
  try {
    await supabase.rpc('update_last_login', { p_user_id: userId });
  } catch (error) {
    // Silently fail - this is non-critical
    console.debug('Last login update failed (non-critical):', error);
  }
}

// Logout user
export async function logout(): Promise<void> {
  localStorage.removeItem(STORAGE_KEY);
  authStore.logout();
}

// Sign up user (typically admin-only, but shows message to get access code)
export async function signup(email: string): Promise<{ success: boolean; error?: string }> {
  try {
    authStore.setLoading(true);
    authStore.setError(null);

    if (!email) {
      throw new Error('Email is required');
    }

    // In CarWhizz, new users get access codes from administrators
    // This would typically be handled by an admin panel
    // For now, we just return a success message
    return {
      success: true
    };
  } catch (error: any) {
    const errorMessage = error.message || 'Sign up failed';
    authStore.setError(errorMessage);
    authStore.setLoading(false);
    return { success: false, error: errorMessage };
  } finally {
    authStore.setLoading(false);
  }
}

// Get current user from localStorage
export async function getCurrentUser(): Promise<User | null> {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) {
      const user: User = JSON.parse(stored);
      authStore.setUser(user);
      return user;
    }
  } catch (error) {
    console.error('Get current user error:', error);
    localStorage.removeItem(STORAGE_KEY);
  }
  return null;
}
