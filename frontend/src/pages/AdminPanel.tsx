import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import AppShell from '../components/AppShell';
import ServiceHealth from '../components/ServiceHealth';
import { api } from '../api/client';
import { useToast } from '../context/ToastContext';

type User = {
  _id?: string;
  id?: string;
  name?: string | null;
  email: string;
  role: 'USER' | 'ADMIN';
  permissions: string[];
  created_at?: string;
};

const PERMISSIONS = ['read:tasks', 'write:tasks', 'delete:tasks', 'manage:users'];

function userId(user: User) {
  return user._id ?? user.id ?? '';
}

export default function AdminPanel() {
  const { showToast } = useToast();
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<User | null>(null);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<'USER' | 'ADMIN'>('USER');
  const [permissions, setPermissions] = useState<string[]>([]);

  const loadUsers = useCallback(async () => {
    setLoading(true);
    try {
      const response = await api.get<User[]>('/users/');
      setUsers(response);
    } catch (error) {
      showToast(error instanceof Error ? error.message : 'Could not load users', 'error');
    } finally {
      setLoading(false);
    }
  }, [showToast]);

  useEffect(() => {
    void loadUsers();
  }, [loadUsers]);

  const adminCount = useMemo(() => users.filter((user) => user.role === 'ADMIN').length, [users]);

  const resetForm = () => {
    setEditing(null);
    setName('');
    setEmail('');
    setPassword('');
    setRole('USER');
    setPermissions([]);
  };

  const editUser = (user: User) => {
    setEditing(user);
    setName(user.name ?? '');
    setEmail(user.email);
    setRole(user.role);
    setPermissions(user.permissions ?? []);
    setPassword('');
  };

  const togglePermission = (permission: string) => {
    setPermissions((current) =>
      current.includes(permission) ? current.filter((item) => item !== permission) : [...current, permission],
    );
  };

  const submitUser = async (event: FormEvent) => {
    event.preventDefault();
    try {
      if (editing) {
        await api.put(`/users/${userId(editing)}`, { name: name || undefined, role, permissions });
        showToast('User updated', 'success');
      } else {
        await api.post('/users/', { name: name || undefined, email, password, role, permissions });
        showToast('User created', 'success');
      }
      resetForm();
      await loadUsers();
    } catch (error) {
      showToast(error instanceof Error ? error.message : 'Could not save user', 'error');
    }
  };

  const deleteUser = async (id: string) => {
    if (!window.confirm('Delete this user?')) {
      return;
    }
    try {
      await api.delete(`/users/${id}`);
      showToast('User deleted', 'success');
      await loadUsers();
    } catch (error) {
      showToast(error instanceof Error ? error.message : 'Could not delete user', 'error');
    }
  };

  return (
    <AppShell>
      <section className="page-head">
        <div>
          <p className="eyebrow">Administration</p>
          <h1>User management</h1>
        </div>
        <div className="metric-row">
          <div className="metric">
            <span className="metric-label">Users</span>
            <strong>{users.length}</strong>
          </div>
          <div className="metric">
            <span className="metric-label">Admins</span>
            <strong>{adminCount}</strong>
          </div>
          <ServiceHealth />
        </div>
      </section>

      <section className="admin-layout">
        <form className="panel form admin-form" onSubmit={submitUser}>
          <h2>{editing ? 'Edit user' : 'Create user'}</h2>
          <label>
            Name
            <input value={name} onChange={(event) => setName(event.target.value)} />
          </label>
          <label>
            Email
            <input
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              type="email"
              disabled={Boolean(editing)}
              required={!editing}
            />
          </label>
          {!editing && (
            <label>
              Password
              <input value={password} onChange={(event) => setPassword(event.target.value)} type="password" required />
            </label>
          )}
          <label>
            Role
            <select value={role} onChange={(event) => setRole(event.target.value as 'USER' | 'ADMIN')}>
              <option value="USER">USER</option>
              <option value="ADMIN">ADMIN</option>
            </select>
          </label>
          <div>
            <span className="field-label">Permissions</span>
            <div className="permission-list">
              {PERMISSIONS.map((permission) => (
                <label className="check-row" key={permission}>
                  <input
                    type="checkbox"
                    checked={permissions.includes(permission)}
                    onChange={() => togglePermission(permission)}
                  />
                  {permission}
                </label>
              ))}
            </div>
          </div>
          <div className="form-actions">
            <button className="button button-primary" type="submit">
              {editing ? 'Update user' : 'Create user'}
            </button>
            {editing && (
              <button className="button button-muted" type="button" onClick={resetForm}>
                Cancel
              </button>
            )}
          </div>
        </form>

        <div className="panel table-panel">
          {loading ? (
            <div className="empty-state">Loading users</div>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Role</th>
                  <th>Permissions</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {users.map((user) => {
                  const id = userId(user);
                  return (
                    <tr key={id}>
                      <td>{user.name || 'Unnamed'}</td>
                      <td>{user.email}</td>
                      <td>
                        <span className={`role-pill role-${user.role.toLowerCase()}`}>{user.role}</span>
                      </td>
                      <td>{user.permissions?.length ? user.permissions.join(', ') : '-'}</td>
                      <td className="table-actions">
                        <button className="button button-muted" type="button" onClick={() => editUser(user)}>
                          Edit
                        </button>
                        <button className="button button-danger" type="button" onClick={() => void deleteUser(id)}>
                          Delete
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      </section>
    </AppShell>
  );
}
