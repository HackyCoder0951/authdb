import React, { useState, useEffect, useContext } from 'react';
import { useToast } from '../context/ToastContext';
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
    const { showToast } = useToast();

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
            showToast('User created successfully', 'success');
            fetchUsers();
        } catch (err: any) {
            // setError(err.response?.data?.detail || 'Failed to create user');
            // handled globally or specifically here if needed
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
            showToast('User updated successfully', 'success');
            fetchUsers();
        } catch (err: any) {
            // setError(err.response?.data?.detail || 'Failed to update user');
        }
    };

    const handleDeleteUser = async (userId: string) => {
        if (!window.confirm('Are you sure you want to delete this user?')) return;
        try {
            await api.delete(`/users/${userId}`);
            showToast('User deleted successfully', 'success');
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

    // Calculate stats
    const totalUsers = users.length;
    const adminCount = users.filter(u => u.role === 'ADMIN').length;

    const logout = () => {
        localStorage.removeItem('token');
        window.location.href = '/login';
    };

    if (loading) return <div style={{ textAlign: 'center', marginTop: '50px', color: 'white' }}>Loading...</div>;

    return (
        <div className="container" style={{ paddingTop: '20px' }}>
            {/* Navigation Header */}
            <div className="glass-panel" style={{ padding: '15px 25px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontWeight: 'bold', fontSize: '1.2rem' }}>
                    <div style={{ background: 'rgba(255,255,255,0.2)', padding: '5px', borderRadius: '8px' }}>
                        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                        </svg>
                    </div>
                    API Admin Panel
                </div>
                <div style={{ display: 'flex', gap: '15px', alignItems: 'center' }}>
                    <span style={{ fontSize: '0.9rem', opacity: 0.8 }}>
                        {auth?.user?.email}
                    </span>
                    <button onClick={logout} style={{ background: 'rgba(255,50,50,0.2)', border: '1px solid rgba(255,50,50,0.3)', color: '#ffcbcb', padding: '5px 12px', borderRadius: '6px', cursor: 'pointer' }}>
                        Sign Out
                    </button>
                </div>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-2" style={{ marginBottom: '30px' }}>
                <div className="glass-panel" style={{ padding: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                        <div style={{ fontSize: '0.9rem', opacity: 0.8, marginBottom: '5px' }}>Total Users</div>
                        <div style={{ fontSize: '2rem', fontWeight: 'bold' }}>{totalUsers}</div>
                    </div>
                    <div style={{ background: 'rgba(255,255,255,0.1)', padding: '10px', borderRadius: '10px' }}>
                        <svg width="30" height="30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                        </svg>
                    </div>
                </div>
                <div className="glass-panel" style={{ padding: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                        <div style={{ fontSize: '0.9rem', opacity: 0.8, marginBottom: '5px' }}>Admins</div>
                        <div style={{ fontSize: '2rem', fontWeight: 'bold' }}>{adminCount}</div>
                    </div>
                    <div style={{ background: 'rgba(16, 185, 129, 0.2)', padding: '10px', borderRadius: '10px' }}>
                        <svg width="30" height="30" fill="none" stroke="#6ee7b7" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                    </div>
                </div>
            </div>

            {/* Actions */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
                <h2 style={{ fontSize: '1.5rem', margin: 0 }}>User Management</h2>
                <button onClick={openCreateModal} className="glass-button" style={{ width: 'auto' }}>
                    + Add User
                </button>
            </div>

            {/* Table */}
            <div className="glass-panel" style={{ padding: '0', overflow: 'hidden' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                    <thead>
                        <tr style={{ background: 'rgba(255,255,255,0.1)', borderBottom: '1px solid rgba(255,255,255,0.1)' }}>
                            <th style={{ padding: '15px 20px', textAlign: 'left', fontSize: '0.9rem', opacity: 0.8 }}>Name</th>
                            <th style={{ padding: '15px 20px', textAlign: 'left', fontSize: '0.9rem', opacity: 0.8 }}>Email</th>
                            <th style={{ padding: '15px 20px', textAlign: 'left', fontSize: '0.9rem', opacity: 0.8 }}>Role</th>
                            <th style={{ padding: '15px 20px', textAlign: 'left', fontSize: '0.9rem', opacity: 0.8 }}>Permissions</th>
                            <th style={{ padding: '15px 20px', textAlign: 'right', fontSize: '0.9rem', opacity: 0.8 }}>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {users.map(user => (
                            <tr key={user._id} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                                <td style={{ padding: '15px 20px' }}>
                                    <div style={{ fontWeight: 500 }}>{user.name || <span style={{ opacity: 0.5 }}>No Name</span>}</div>
                                </td>
                                <td style={{ padding: '15px 20px' }}>{user.email}</td>
                                <td style={{ padding: '15px 20px' }}>
                                    <span style={{
                                        padding: '4px 10px',
                                        borderRadius: '20px',
                                        fontSize: '0.8rem',
                                        background: user.role === 'ADMIN' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(255, 255, 255, 0.1)',
                                        color: user.role === 'ADMIN' ? '#6ee7b7' : 'white',
                                        border: '1px solid rgba(255,255,255,0.1)'
                                    }}>
                                        {user.role}
                                    </span>
                                </td>
                                <td style={{ padding: '15px 20px' }}>
                                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '5px' }}>
                                        {user.permissions.length > 0 ? user.permissions.map(perm => (
                                            <span key={perm} style={{ fontSize: '0.75rem', padding: '2px 8px', background: 'rgba(255,255,255,0.1)', borderRadius: '4px', opacity: 0.8 }}>
                                                {perm}
                                            </span>
                                        )) : <span style={{ opacity: 0.4 }}>-</span>}
                                    </div>
                                </td>
                                <td style={{ padding: '15px 20px', textAlign: 'right' }}>
                                    <button onClick={() => openEditModal(user)} style={{ background: 'none', border: 'none', color: '#93c5fd', cursor: 'pointer', marginRight: '10px' }}>Edit</button>
                                    <button onClick={() => handleDeleteUser(user._id)} style={{ background: 'none', border: 'none', color: '#fca5a5', cursor: 'pointer' }}>Delete</button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {showModal && (
                <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(5px)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 1000 }}>
                    <div className="glass-panel" style={{ width: '100%', maxWidth: '500px', padding: '30px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '25px' }}>
                            <h2 style={{ margin: 0 }}>{editingUser ? 'Edit User' : 'Add New User'}</h2>
                            <button onClick={() => setShowModal(false)} style={{ background: 'none', border: 'none', color: 'white', fontSize: '1.5rem', cursor: 'pointer', opacity: 0.7 }}>×</button>
                        </div>

                        {error && <div style={{ background: 'rgba(239, 68, 68, 0.2)', color: '#fca5a5', padding: '12px', borderRadius: '8px', marginBottom: '20px', border: '1px solid rgba(239, 68, 68, 0.3)' }}>{error}</div>}

                        <form onSubmit={editingUser ? handleUpdateUser : handleCreateUser}>
                            <div style={{ marginBottom: '20px' }}>
                                <label style={{ display: 'block', marginBottom: '8px', opacity: 0.9 }}>Full Name (Optional)</label>
                                <input
                                    className="glass-input"
                                    type="text"
                                    value={name}
                                    onChange={e => setName(e.target.value)}
                                    placeholder="John Doe"
                                />
                            </div>
                            {!editingUser && (
                                <div style={{ marginBottom: '20px' }}>
                                    <label style={{ display: 'block', marginBottom: '8px', opacity: 0.9 }}>Email</label>
                                    <input
                                        className="glass-input"
                                        type="email"
                                        value={email}
                                        onChange={e => setEmail(e.target.value)}
                                        required
                                        placeholder="you@example.com"
                                    />
                                </div>
                            )}
                            {!editingUser && (
                                <div style={{ marginBottom: '20px' }}>
                                    <label style={{ display: 'block', marginBottom: '8px', opacity: 0.9 }}>Password</label>
                                    <input
                                        className="glass-input"
                                        type="password"
                                        value={password}
                                        onChange={e => setPassword(e.target.value)}
                                        required
                                        placeholder="••••••••"
                                    />
                                </div>
                            )}
                            <div style={{ marginBottom: '20px' }}>
                                <label style={{ display: 'block', marginBottom: '8px', opacity: 0.9 }}>Role</label>
                                <select
                                    className="glass-input"
                                    value={role}
                                    onChange={e => setRole(e.target.value)}
                                >
                                    <option style={{ color: 'black' }} value="USER">User</option>
                                    <option style={{ color: 'black' }} value="ADMIN">Admin</option>
                                </select>
                            </div>
                            <div style={{ marginBottom: '30px', position: 'relative' }}>
                                <label style={{ display: 'block', marginBottom: '8px', opacity: 0.9 }}>Permissions</label>
                                <div
                                    className="glass-input"
                                    onClick={() => setIsPermDropdownOpen(!isPermDropdownOpen)}
                                    style={{ cursor: 'pointer', minHeight: '44px', display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: '5px' }}
                                >
                                    {permissions.length === 0 ? (
                                        <span style={{ opacity: 0.6 }}>Select permissions...</span>
                                    ) : (
                                        permissions.map(perm => (
                                            <span key={perm} style={{ display: 'inline-flex', alignItems: 'center', background: 'rgba(255,255,255,0.2)', padding: '2px 8px', borderRadius: '4px', fontSize: '0.8rem' }}>
                                                {perm}
                                                <span
                                                    style={{ marginLeft: '6px', cursor: 'pointer', fontWeight: 'bold' }}
                                                    onClick={(e) => {
                                                        e.stopPropagation();
                                                        togglePermission(perm);
                                                    }}
                                                >
                                                    ×
                                                </span>
                                            </span>
                                        ))
                                    )}
                                </div>
                                {isPermDropdownOpen && (
                                    <div style={{ position: 'absolute', top: '100%', left: 0, right: 0, background: 'rgba(30, 41, 59, 0.95)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', marginTop: '5px', zIndex: 10, overflow: 'hidden', backdropFilter: 'blur(10px)' }}>
                                        {AVAILABLE_PERMISSIONS.map(perm => (
                                            <div
                                                key={perm}
                                                onClick={() => togglePermission(perm)}
                                                style={{
                                                    display: 'flex',
                                                    alignItems: 'center',
                                                    padding: '12px 15px',
                                                    cursor: 'pointer',
                                                    borderBottom: '1px solid rgba(255,255,255,0.05)',
                                                    background: permissions.includes(perm) ? 'rgba(255,255,255,0.1)' : 'transparent'
                                                }}
                                            >
                                                <div style={{
                                                    width: '18px',
                                                    height: '18px',
                                                    border: '1px solid rgba(255,255,255,0.3)',
                                                    borderRadius: '4px',
                                                    marginRight: '10px',
                                                    display: 'flex',
                                                    alignItems: 'center',
                                                    justifyContent: 'center',
                                                    background: permissions.includes(perm) ? 'var(--primary-color)' : 'transparent',
                                                    borderColor: permissions.includes(perm) ? 'transparent' : 'rgba(255,255,255,0.3)'
                                                }}>
                                                    {permissions.includes(perm) && <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="4"><path d="M20 6L9 17l-5-5" /></svg>}
                                                </div>
                                                {perm}
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>
                            <div style={{ display: 'flex', gap: '15px' }}>
                                <button type="button" onClick={() => setShowModal(false)} className="glass-button" style={{ background: 'rgba(255,255,255,0.1)' }}>Cancel</button>
                                <button type="submit" className="glass-button">
                                    {editingUser ? 'Update User' : 'Create User'}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
};

export default AdminPanel;
