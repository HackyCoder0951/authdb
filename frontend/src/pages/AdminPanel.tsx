import React, { useState, useEffect, useContext } from 'react';
import api from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

interface User {
    _id: string;
    email: string;
    role: string;
    permissions: string[];
    created_at: string;
}

const AdminPanel: React.FC = () => {
    const auth = useContext(AuthContext);
    const navigate = useNavigate();
    const [users, setUsers] = useState<User[]>([]);
    const [loading, setLoading] = useState(true);
    const [showModal, setShowModal] = useState(false);
    const [editingUser, setEditingUser] = useState<User | null>(null);

    // Form state
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [role, setRole] = useState('USER');
    const [permissions, setPermissions] = useState('');
    const [error, setError] = useState('');

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
            const permsArray = permissions.split(',').map(p => p.trim()).filter(p => p);
            await api.post('/users/', {
                email,
                password,
                role,
                permissions: permsArray
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
            const permsArray = permissions.split(',').map(p => p.trim()).filter(p => p);
            await api.put(`/users/${editingUser._id}`, {
                role,
                permissions: permsArray
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
        setEmail(user.email);
        setRole(user.role);
        setPermissions(user.permissions.join(', '));
        setPassword(''); // Not updating password here for simplicity
        setShowModal(true);
    };

    const resetForm = () => {
        setEmail('');
        setPassword('');
        setRole('USER');
        setPermissions('');
        setError('');
    };

    if (loading) return <div className="container" style={{ textAlign: 'center', marginTop: '50px' }}>Loading...</div>;

    return (
        <div className="container fade-in">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' }}>
                <h1>Admin Panel</h1>
                <div style={{ display: 'flex', gap: '10px' }}>
                    <button onClick={() => navigate('/dashboard')} className="glass-button" style={{ background: 'rgba(255,255,255,0.2)' }}>Dashboard</button>
                    <button onClick={openCreateModal} className="glass-button">Add User</button>
                </div>
            </div>

            <div className="glass-panel" style={{ overflowX: 'auto' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                    <thead>
                        <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.1)' }}>
                            <th style={{ padding: '15px' }}>Email</th>
                            <th style={{ padding: '15px' }}>Role</th>
                            <th style={{ padding: '15px' }}>Permissions</th>
                            <th style={{ padding: '15px' }}>Created At</th>
                            <th style={{ padding: '15px' }}>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {users.map(user => (
                            <tr key={user._id} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                                <td style={{ padding: '15px' }}>{user.email}</td>
                                <td style={{ padding: '15px' }}>
                                    <span style={{
                                        padding: '5px 10px',
                                        borderRadius: '20px',
                                        background: user.role === 'ADMIN' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(59, 130, 246, 0.2)',
                                        color: user.role === 'ADMIN' ? '#10b981' : '#60a5fa',
                                        fontSize: '0.8rem',
                                        fontWeight: 'bold'
                                    }}>
                                        {user.role}
                                    </span>
                                </td>
                                <td style={{ padding: '15px' }}>{user.permissions.join(', ') || '-'}</td>
                                <td style={{ padding: '15px' }}>{new Date(user.created_at).toLocaleDateString()}</td>
                                <td style={{ padding: '15px' }}>
                                    <button onClick={() => openEditModal(user)} style={{ marginRight: '10px', background: 'none', border: 'none', color: '#60a5fa', cursor: 'pointer' }}>Edit</button>
                                    <button onClick={() => handleDeleteUser(user._id)} style={{ background: 'none', border: 'none', color: '#ef4444', cursor: 'pointer' }}>Delete</button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {showModal && (
                <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 1000 }}>
                    <div className="glass-panel" style={{ width: '90%', maxWidth: '500px', padding: '30px' }}>
                        <h2>{editingUser ? 'Edit User' : 'Add New User'}</h2>
                        {error && <div style={{ color: '#ef4444', marginBottom: '15px' }}>{error}</div>}
                        <form onSubmit={editingUser ? handleUpdateUser : handleCreateUser}>
                            {!editingUser && (
                                <div style={{ marginBottom: '15px' }}>
                                    <label style={{ display: 'block', marginBottom: '5px' }}>Email</label>
                                    <input className="glass-input" type="email" value={email} onChange={e => setEmail(e.target.value)} required />
                                </div>
                            )}
                            {!editingUser && (
                                <div style={{ marginBottom: '15px' }}>
                                    <label style={{ display: 'block', marginBottom: '5px' }}>Password</label>
                                    <input className="glass-input" type="password" value={password} onChange={e => setPassword(e.target.value)} required />
                                </div>
                            )}
                            <div style={{ marginBottom: '15px' }}>
                                <label style={{ display: 'block', marginBottom: '5px' }}>Role</label>
                                <select className="glass-input" value={role} onChange={e => setRole(e.target.value)} style={{ color: 'black' }}>
                                    <option value="USER">User</option>
                                    <option value="ADMIN">Admin</option>
                                </select>
                            </div>
                            <div style={{ marginBottom: '20px' }}>
                                <label style={{ display: 'block', marginBottom: '5px' }}>Permissions (comma separated)</label>
                                <input className="glass-input" type="text" value={permissions} onChange={e => setPermissions(e.target.value)} placeholder="read:tasks, write:tasks" />
                            </div>
                            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
                                <button type="button" onClick={() => setShowModal(false)} className="glass-button" style={{ background: 'rgba(255,255,255,0.1)' }}>Cancel</button>
                                <button type="submit" className="glass-button">{editingUser ? 'Update' : 'Create'}</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
};

export default AdminPanel;
