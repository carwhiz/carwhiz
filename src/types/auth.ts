export interface User {
  id: string;
  email: string;
  phone_number: string;
  role: string;
  created_at: string;
}

export interface LoginPayload {
  password: string;
}

export interface AuthState {
  user: User | null;
  loading: boolean;
  error: string | null;
  isAuthenticated: boolean;
}
