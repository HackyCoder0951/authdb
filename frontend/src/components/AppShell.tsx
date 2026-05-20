import type { ReactNode } from 'react';
import { Link, NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function AppShell({ children }: { children: ReactNode }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const signOut = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="app-shell">
      <header className="topbar">
        <Link to="/admin" className="brand">
          <span className="brand-mark">A</span>
          <span>AuthDB</span>
        </Link>
        <nav className="nav-links">
          <NavLink to="/dashboard">Tasks</NavLink>
          {user?.role === 'ADMIN' && <NavLink to="/admin">Admin</NavLink>}
        </nav>
        <div className="user-strip">
          <span>{user?.name || user?.email || 'User'}</span>
          <button className="button button-muted" type="button" onClick={signOut}>
            Sign out
          </button>
        </div>
      </header>
      <main className="main-content">{children}</main>
    </div>
  );
}
