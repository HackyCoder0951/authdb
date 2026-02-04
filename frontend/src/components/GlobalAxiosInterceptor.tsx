import React, { useEffect } from 'react';
import api from '../api/axios';
import { useToast } from '../context/ToastContext';

export const GlobalAxiosInterceptor: React.FC = () => {
    const { showToast } = useToast();

    useEffect(() => {
        const interceptor = api.interceptors.response.use(
            (response) => {
                // If the backend sends a success message in a standard format, we could show it here.
                // For now, we rely on local components for "Success" toasts as per current implementation.
                return response;
            },
            (error) => {
                const status = error.response?.status;
                const url = error.config?.url;
                const backendMessage = error.response?.data?.detail;

                // 1. Network / Server Errors
                if (!error.response) {
                    showToast('Network error. Unable to reach server.', 'error');
                    return Promise.reject(error);
                }

                if (status >= 500) {
                    showToast('Server error. Please try again later.', 'error');
                    return Promise.reject(error);
                }

                // 2. Authentication Errors (401)
                if (status === 401) {
                    if (url?.includes('/auth/login')) {
                        // Login attempt failed
                        showToast('Invalid credentials. Please check your email and password.', 'error');
                    } else {
                        // Token expired or invalid during a request
                        showToast('Token expired. Please login again.', 'error');

                        // Clear token and redirect to login
                        localStorage.removeItem('token');
                        if (window.location.pathname !== '/login' && window.location.pathname !== '/register') {
                            setTimeout(() => { window.location.href = '/login'; }, 1500);
                        }
                    }
                }

                // 3. Authorization Errors (403)
                else if (status === 403) {
                    showToast('Unauthorized. You do not have permission to perform this action.', 'error');
                }

                // 4. Not Found (404)
                else if (status === 404) {
                    if (url?.includes('/users/')) {
                        showToast('User not found.', 'error');
                    } else if (url?.includes('/tasks/')) {
                        showToast('Task not found.', 'error');
                    } else {
                        showToast('Resource not found.', 'error');
                    }
                }

                // 5. Conflicts (409) - e.g. Duplicate Email
                else if (status === 409) {
                    showToast(backendMessage || 'Resource already exists.', 'error');
                }

                // 6. Bad Request (400) - e.g. Validation logic that isn't Pydantic default
                else if (status === 400) {
                    showToast(backendMessage || 'Invalid request.', 'error');
                }

                // Fallback for other errors
                // We typically ignore 422 (Unprocessable Entity) here as it's often form field validation 
                // that is better displayed inline next to inputs.
                else if (status !== 422) {
                    const fallbackMsg = typeof backendMessage === 'string' ? backendMessage : 'An unexpected error occurred';
                    showToast(fallbackMsg, 'error');
                }

                return Promise.reject(error);
            }
        );

        return () => {
            api.interceptors.response.eject(interceptor);
        };
    }, [showToast]);

    return null;
};
