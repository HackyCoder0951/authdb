import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { api } from '../api/client';

type JwtUser = {
  sub: string;
  exp: number;
  role?: string;
  email?: string;
  name?: string;
  permissions?: string[];
};

type UserProfile = {
  id: string;
  role?: string;
  email?: string;
  name?: string | null;
  permissions?: string[];
};

type AuthContextValue = {
  user: JwtUser | null;
  token: string | null;
  loading: boolean;
  isAuthenticated: boolean;
  login: (token: string) => void;
  logout: () => void;
};

const TOKEN_KEY = 'authdb_token';
const AuthContext = createContext<AuthContextValue | undefined>(undefined);

function decodeToken(token: string): JwtUser {
  const [, payload] = token.split('.');
  if (!payload) {
    throw new Error('Invalid token');
  }
  const normalized = payload.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  return JSON.parse(atob(padded)) as JwtUser;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(() => localStorage.getItem(TOKEN_KEY));
  const [user, setUser] = useState<JwtUser | null>(null);
  const [loading, setLoading] = useState(true);

  const logout = () => {
    localStorage.removeItem(TOKEN_KEY);
    setToken(null);
    setUser(null);
  };

  const login = (newToken: string) => {
    localStorage.setItem(TOKEN_KEY, newToken);
    setToken(newToken);
  };

  useEffect(() => {
    if (!token) {
      setUser(null);
      setLoading(false);
      return;
    }

    try {
      const decoded = decodeToken(token);
      if (decoded.exp * 1000 <= Date.now()) {
        logout();
        return;
      }
      const baseUser = { ...decoded, role: decoded.role ?? 'USER', permissions: decoded.permissions ?? [] };
      setUser(baseUser);
      setLoading(true);

      let isActive = true;
      void (async () => {
        try {
          const profile = await api.get<UserProfile>(`/users/${decoded.sub}`);
          if (!isActive) {
            return;
          }
          setUser({
            ...baseUser,
            role: profile.role ?? baseUser.role,
            permissions: profile.permissions ?? baseUser.permissions,
            name: profile.name ?? baseUser.name,
            email: profile.email ?? baseUser.email,
          });
        } catch {
          if (isActive) {
            setUser(baseUser);
          }
        } finally {
          if (isActive) {
            setLoading(false);
          }
        }
      })();

      return () => {
        isActive = false;
      };
    } catch {
      logout();
    }
  }, [token]);

  const value = useMemo(
    () => ({ user, token, loading, isAuthenticated: Boolean(user), login, logout }),
    [user, token, loading],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return value;
}
