import React, { useState, useEffect, useContext } from 'react';
import api from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

interface User {
    _id: string;
    email: string;
    name?: string;
    role: string;
    permissions: string[];
    created_at: string;
}

const AVAILABLE_PERMISSIONS = ['read:tasks', 'write:tasks', 'delete:tasks', 'manage:users'];

const AdminPanel: React.FC = () => {
    const auth = useContext(AuthContext);
    const navigate = useNavigate();
    const [users, setUsers] = useState<User[]>([]);
    const [loading, setLoading] = useState(true);
    const [showModal, setShowModal] = useState(false);
    const [editingUser, setEditingUser] = useState<User | null>(null);

    // Form state
    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [role, setRole] = useState('USER');
    const [permissions, setPermissions] = useState<string[]>([]);
    const [error, setError] = useState('');
    const [isPermDropdownOpen, setIsPermDropdownOpen] = useState(false);

    useEffect(() => {
        if (auth?.isAuthenticated && auth.user?.role === 'ADMIN') {
            fetchUsers();
        } else if (auth?.isAuthenticated) {
            navigate('/dashboard');
        } else {
            navigate('/login');
        }
    }, [auth]);

    const fetchUsers = async () => {
        setLoading(true);
        try {
            const response = await api.get('/users/');
            setUsers(response.data);
        } catch (err) {
            console.error('Failed to fetch users', err);
        } finally {
            setLoading(false);
        }
    };

    const handleCreateUser = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        try {
            await api.post('/users/', {
                name: name || undefined,
                email,
                password,
                role,
                permissions
            });
            setShowModal(false);
            resetForm();
            fetchUsers();
        } catch (err: any) {
            setError(err.response?.data?.detail || 'Failed to create user');
        }
    };

    const handleUpdateUser = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!editingUser) return;
        setError('');
        try {
            await api.put(`/users/${editingUser._id}`, {
                name: name || undefined,
                role,
                permissions
            });
            setShowModal(false);
            resetForm();
            fetchUsers();
        } catch (err: any) {
            setError(err.response?.data?.detail || 'Failed to update user');
        }
    };

    const handleDeleteUser = async (userId: string) => {
        if (!window.confirm('Are you sure you want to delete this user?')) return;
        try {
            await api.delete(`/users/${userId}`);
            fetchUsers();
        } catch (err) {
            console.error('Failed to delete user', err);
        }
    };

    const openCreateModal = () => {
        setEditingUser(null);
        resetForm();
        setShowModal(true);
    };

    const openEditModal = (user: User) => {
        setEditingUser(user);
        setName(user.name || '');
        setEmail(user.email);
        setRole(user.role);
        setPermissions(user.permissions || []);
        setPassword(''); // Not updating password here for simplicity
        setShowModal(true);
    };

    const resetForm = () => {
        setName('');
        setEmail('');
        setPassword('');
        setRole('USER');
        setPermissions([]);
        setError('');
        setIsPermDropdownOpen(false);
    };

    const togglePermission = (perm: string) => {
        if (permissions.includes(perm)) {
            setPermissions(permissions.filter(p => p !== perm));
        } else {
            setPermissions([...permissions, perm]);
        }
    };

    if (loading) return <div style={{ textAlign: 'center', marginTop: '50px', color: '#374151' }}>Loading...</div>;

    return (
        <div style={{ maxWidth: '1200px', margin: '0 auto', padding: '20px', fontFamily: 'sans-serif' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px', flexWrap: 'wrap', gap: '15px' }}>
                <h1 style={{ margin: 0, color: '#111827' }}>Admin Panel</h1>
                <div style={{ display: 'flex', gap: '10px' }}>
                    <button onClick={() => navigate('/dashboard')} style={{ padding: '8px 16px', background: '#374151', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer' }}>Dashboard</button>
                    <button onClick={openCreateModal} style={{ padding: '8px 16px', background: '#3b82f6', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer' }}>Add User</button>
                </div>
            </div>

            {/* Responsive Table / Card Grid */}
            <div style={{ overflowX: 'auto', background: 'white', borderRadius: '8px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '800px' }}>
                    <thead style={{ background: '#f9fafb' }}>
                        <tr>
                            <th style={{ padding: '15px', borderBottom: '1px solid #e5e7eb', color: '#6b7280', fontWeight: 600 }}>Name</th>
                            <th style={{ padding: '15px', borderBottom: '1px solid #e5e7eb', color: '#6b7280', fontWeight: 600 }}>Email</th>
                            <th style={{ padding: '15px', borderBottom: '1px solid #e5e7eb', color: '#6b7280', fontWeight: 600 }}>Role</th>
                            <th style={{ padding: '15px', borderBottom: '1px solid #e5e7eb', color: '#6b7280', fontWeight: 600 }}>Permissions</th>
                            <th style={{ padding: '15px', borderBottom: '1px solid #e5e7eb', color: '#6b7280', fontWeight: 600 }}>Created</th>
                            <th style={{ padding: '15px', borderBottom: '1px solid #e5e7eb', color: '#6b7280', fontWeight: 600 }}>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {users.map(user => (
                            <tr key={user._id} style={{ borderBottom: '1px solid #e5e7eb' }}>
                                <td style={{ padding: '15px', color: '#111827' }}>
                                    {user.name || <span style={{ color: '#9ca3af', fontStyle: 'italic' }}>No Name</span>}
                                </td>
                                <td style={{ padding: '15px', color: '#374151' }}>{user.email}</td>
                                <td style={{ padding: '15px' }}>
                                    <span style={{
                                        padding: '4px 10px',
                                        borderRadius: '9999px',
                                        background: user.role === 'ADMIN' ? '#d1fae5' : '#dbeafe',
                                        color: user.role === 'ADMIN' ? '#059669' : '#1d4ed8',
                                        fontSize: '0.75rem',
                                        fontWeight: 700
                                    }}>
                                        {user.role}
                                    </span>
                                </td>
                                <td style={{ padding: '15px', color: '#6b7280', fontSize: '0.875rem' }}>{user.permissions.join(', ') || '-'}</td>
                                <td style={{ padding: '15px', color: '#6b7280' }}>{new Date(user.created_at).toLocaleDateString()}</td>
                                <td style={{ padding: '15px' }}>
                                    <button onClick={() => openEditModal(user)} style={{ marginRight: '10px', background: 'none', border: 'none', color: '#3b82f6', cursor: 'pointer', fontWeight: 500 }}>Edit</button>
                                    <button onClick={() => handleDeleteUser(user._id)} style={{ background: 'none', border: 'none', color: '#ef4444', cursor: 'pointer', fontWeight: 500 }}>Delete</button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {/* Mobile View Placeholder for very small screens if table overflows */}
            <div style={{ marginTop: '10px', fontSize: '0.875rem', color: '#6b7280', textAlign: 'center', display: 'none' }}>
                Scroll horizontally to view table on small screens
            </div>

            {showModal && (
                <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 1000, padding: '20px' }}>
                    <div style={{ background: 'white', width: '100%', maxWidth: '500px', padding: '30px', borderRadius: '12px', boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)' }}>
                        <h2 style={{ marginTop: 0, marginBottom: '20px', color: '#111827' }}>{editingUser ? 'Edit User' : 'Add New User'}</h2>
                        {error && <div style={{ background: '#fee2e2', color: '#b91c1c', padding: '10px', borderRadius: '6px', marginBottom: '15px', fontSize: '0.875rem' }}>{error}</div>}
                        <form onSubmit={editingUser ? handleUpdateUser : handleCreateUser}>
                            <div style={{ marginBottom: '15px' }}>
                                <label style={{ display: 'block', marginBottom: '5px', fontSize: '0.875rem', fontWeight: 500, color: '#374151' }}>Full Name (Optional)</label>
                                <input
                                    type="text"
                                    value={name}
                                    onChange={e => setName(e.target.value)}
                                    placeholder="John Doe"
                                    style={{ width: '100%', padding: '10px', borderRadius: '6px', border: '1px solid #d1d5db' }}
                                />
                            </div>
                            {!editingUser && (
                                <div style={{ marginBottom: '15px' }}>
                                    <label style={{ display: 'block', marginBottom: '5px', fontSize: '0.875rem', fontWeight: 500, color: '#374151' }}>Email</label>
                                    <input
                                        type="email"
                                        value={email}
                                        onChange={e => setEmail(e.target.value)}
                                        required
                                        placeholder="you@example.com"
                                        style={{ width: '100%', padding: '10px', borderRadius: '6px', border: '1px solid #d1d5db' }}
                                    />
                                </div>
                            )}
                            {!editingUser && (
                                <div style={{ marginBottom: '15px' }}>
                                    <label style={{ display: 'block', marginBottom: '5px', fontSize: '0.875rem', fontWeight: 500, color: '#374151' }}>Password</label>
                                    <input
                                        type="password"
                                        value={password}
                                        onChange={e => setPassword(e.target.value)}
                                        required
                                        placeholder="••••••••"
                                        style={{ width: '100%', padding: '10px', borderRadius: '6px', border: '1px solid #d1d5db' }}
                                    />
                                </div>
                            )}
                            <div style={{ marginBottom: '15px' }}>
                                <label style={{ display: 'block', marginBottom: '5px', fontSize: '0.875rem', fontWeight: 500, color: '#374151' }}>Role</label>
                                <select
                                    value={role}
                                    onChange={e => setRole(e.target.value)}
                                    style={{ width: '100%', padding: '10px', borderRadius: '6px', border: '1px solid #d1d5db', backgroundColor: 'white' }}
                                >
                                    <option value="USER">User</option>
                                    <option value="ADMIN">Admin</option>
                                </select>
                            </div>
                            <div style={{ marginBottom: '20px', position: 'relative' }}>
                                <label style={{ display: 'block', marginBottom: '5px', fontSize: '0.875rem', fontWeight: 500, color: '#374151' }}>Permissions</label>
                                <div
                                    onClick={() => setIsPermDropdownOpen(!isPermDropdownOpen)}
                                    style={{ width: '100%', padding: '10px', borderRadius: '6px', border: '1px solid #d1d5db', background: 'white', cursor: 'pointer', minHeight: '42px', display: 'flex', alignItems: 'center' }}
                                >
                                    {permissions.length === 0 ? <span style={{ color: '#9ca3af' }}>Select permissions...</span> : permissions.join(', ')}
                                </div>
                                {isPermDropdownOpen && (
                                    <div style={{ position: 'absolute', top: '100%', left: 0, right: 0, background: 'white', border: '1px solid #e5e7eb', borderRadius: '6px', boxShadow: '0 4px 6px -1px rgba(0,0,0,0.1)', marginTop: '4px', zIndex: 10 }}>
                                        {AVAILABLE_PERMISSIONS.map(perm => (
                                            <label key={perm} style={{ display: 'flex', alignItems: 'center', padding: '10px', cursor: 'pointer', borderBottom: '1px solid #f3f4f6' }}>
                                                <input
                                                    type="checkbox"
                                                    checked={permissions.includes(perm)}
                                                    onChange={() => togglePermission(perm)}
                                                    style={{ marginRight: '10px' }}
                                                />
                                                {perm}
                                            </label>
                                        ))}
                                    </div>
                                )}
                            </div>
                            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
                                <button type="button" onClick={() => setShowModal(false)} style={{ padding: '8px 16px', background: 'white', color: '#374151', border: '1px solid #d1d5db', borderRadius: '6px', cursor: 'pointer' }}>Cancel</button>
                                <button type="submit" style={{ padding: '8px 16px', background: '#3b82f6', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer' }}>{editingUser ? 'Update' : 'Create'}</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
};

export default AdminPanel;
