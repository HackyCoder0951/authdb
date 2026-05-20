import { FormEvent, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api } from '../api/client';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';

type LoginResponse = { access_token: string; token_type: string };

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const { login } = useAuth();
  const { showToast } = useToast();
  const navigate = useNavigate();

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setSubmitting(true);
    try {
      const form = new URLSearchParams();
      form.set('username', email);
      form.set('password', password);
      const response = await api.post<LoginResponse>('/auth/login', form.toString(), {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      });
      login(response.access_token);
      showToast('Signed in successfully', 'success');
      navigate('/dashboard');
    } catch (error) {
      showToast(error instanceof Error ? error.message : 'Could not sign in', 'error');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <section className="auth-screen">
      <div className="auth-card">
        <p className="eyebrow">AuthDB</p>
        <h1>Sign in</h1>
        <form className="form" onSubmit={handleSubmit}>
          <label>
            Email
            <input value={email} onChange={(event) => setEmail(event.target.value)} type="email" required />
          </label>
          <label>
            Password
            <input value={password} onChange={(event) => setPassword(event.target.value)} type="password" required />
          </label>
          <button className="button button-primary" type="submit" disabled={submitting}>
            {submitting ? 'Signing in' : 'Sign in'}
          </button>
        </form>
        <p className="auth-switch">
          Need an account? <Link to="/register">Create one</Link>
        </p>
      </div>
    </section>
  );
}
