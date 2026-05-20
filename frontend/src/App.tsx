import type { ReactNode } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import AdminPanel from './pages/AdminPanel';
import Dashboard from './pages/Dashboard';
import Login from './pages/Login';
import Register from './pages/Register';

function ProtectedRoute({ children, adminOnly = false }: { children: ReactNode; adminOnly?: boolean }) {
  const { isAuthenticated, loading, user } = useAuth();

  if (loading) {
    return <div className="screen-center">Loading</div>;
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  if (adminOnly && user?.role !== 'ADMIN') {
    return <Navigate to="/dashboard" replace />;
  }

  return children;
}

export default function App() {
  const { isAuthenticated, loading, user } = useAuth();
  const defaultRoute = !loading && isAuthenticated && user?.role === 'ADMIN' ? '/admin' : '/dashboard';

  return (
    <Routes>
      <Route path="/login" element={!loading && isAuthenticated ? <Navigate to={defaultRoute} replace /> : <Login />} />
      <Route path="/register" element={!loading && isAuthenticated ? <Navigate to={defaultRoute} replace /> : <Register />} />
      <Route
        path="/dashboard"
        element={
          <ProtectedRoute>
            {user?.role === 'ADMIN' ? <Navigate to="/admin" replace /> : <Dashboard />}
          </ProtectedRoute>
        }
      />
      <Route
        path="/admin"
        element={
          <ProtectedRoute adminOnly>
            <AdminPanel />
          </ProtectedRoute>
        }
      />
      <Route path="/" element={<Navigate to={defaultRoute} replace />} />
      <Route path="*" element={<Navigate to={defaultRoute} replace />} />
    </Routes>
  );
}
