import React, { createContext, useState, useEffect } from 'react';
import type { ReactNode } from 'react';
import { jwtDecode } from 'jwt-decode';

interface User {
    sub: string;
    exp: number;
    role: string;
}

interface AuthContextType {
    user: User | null;
    token: string | null;
    login: (token: string) => void;
    logout: () => void;
    isAuthenticated: boolean;
}

export const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
    const [user, setUser] = useState<User | null>(null);
    const [token, setToken] = useState<string | null>(localStorage.getItem('token'));

    useEffect(() => {
        if (token) {
            try {
                const decoded = jwtDecode<User>(token);
                // Check expiry
                if (decoded.exp * 1000 < Date.now()) {
                    console.log('AuthContext: Token expired, logging out');
                    logout();
                } else {
                    console.log('AuthContext: User authenticated', decoded);
                    setUser(decoded);
                }
            } catch (error) {
                console.error('AuthContext: Token decode failed', error);
                logout();
            }
        } else {
            console.log('AuthContext: No token found');
            setUser(null);
        }
    }, [token]);

    const login = (newToken: string) => {
        console.log('AuthContext: Logging in');
        localStorage.setItem('token', newToken);
        setToken(newToken);
    };

    const logout = () => {
        console.log('AuthContext: Logging out');
        localStorage.removeItem('token');
        setToken(null);
        setUser(null);
    };

    return (
        <AuthContext.Provider value={{ user, token, login, logout, isAuthenticated: !!user }}>
            {children}
        </AuthContext.Provider>
    );
};
