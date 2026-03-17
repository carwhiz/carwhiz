import { supabase } from '../supabaseClient';
import type { SignUpPayload, LoginPayload, User } from '../../types/auth';
import { authStore } from '../../stores/authStore';

const STORAGE_KEY = 'carwhizz_user';

// Validate 6-digit password/code
export function validatePassword(password: string): boolean {
  const passwordRegex = /^\d{6}$/;
  return passwordRegex.test(password);
}

// Validate email
export function validateEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// Validate phone number (basic validation, customize as needed)
export function validatePhoneNumber(phone: string): boolean {
  const phoneRegex = /^[+]?[(]?[0-9]{3}[)]?[-\s]?[0-9]{3}[-\s]?[0-9]{4,6}$/;
  return phoneRegex.test(phone.replace(/\s/g, ''));
}

// Sign up user via custom RPC
export async function signUp(payload: SignUpPayload): Promise<{ success: boolean; error?: string }> {
  try {
    authStore.setLoading(true);
    authStore.setError(null);

    // Validate inputs
    if (!validateEmail(payload.email)) {
      throw new Error('Invalid email format');
    }
    if (!validatePhoneNumber(payload.phone_number)) {
      throw new Error('Invalid phone number format');
    }
    if (!validatePassword(payload.password)) {
      throw new Error('Password must be exactly 6 digits');
    }

    // Register via custom RPC function
    const { data, error } = await supabase.rpc('register_user', {
      p_email: payload.email,
      p_phone_number: payload.phone_number,
      p_password: payload.password,
    });

    if (error) {
      throw error;
    }

    if (data?.error) {
      throw new Error(data.error);
    }

    authStore.setLoading(false);
    return { success: true };
  } catch (error: any) {
    const errorMessage = error?.message || 'Sign up failed';
    authStore.setError(errorMessage);
    authStore.setLoading(false);
    return { success: false, error: errorMessage };
  }
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

    // Authenticate via access code RPC function
    const { data, error } = await supabase.rpc('authenticate_by_code', {
      p_password: payload.password,
    });

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

    // Persist session in localStorage
    localStorage.setItem(STORAGE_KEY, JSON.stringify(user));
    authStore.setUser(user);
    authStore.setLoading(false);
    return { success: true };
  } catch (error: any) {
    const errorMessage = error?.message || 'Login failed';
    authStore.setError(errorMessage);
    authStore.setLoading(false);
    return { success: false, error: errorMessage };
  }
}

// Logout user
export async function logout(): Promise<void> {
  localStorage.removeItem(STORAGE_KEY);
  authStore.logout();
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
