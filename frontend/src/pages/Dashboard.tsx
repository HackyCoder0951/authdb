import React, { useState, useEffect, useContext } from 'react';
import { useToast } from '../context/ToastContext';
import api from '../api/axios';
import { AuthContext } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

interface Task {
    _id: string;
    title: string;
    description?: string;
    owner_id: string;
}

const Dashboard: React.FC = () => {
    const auth = useContext(AuthContext);
    const [tasks, setTasks] = useState<Task[]>([]);
    const [newTaskTitle, setNewTaskTitle] = useState('');
    const [newTaskDesc, setNewTaskDesc] = useState('');
    const { showToast } = useToast();
    const navigate = useNavigate();

    useEffect(() => {
        if (auth?.loading) return; // Wait for auth to initialize
        if (!auth?.isAuthenticated) {
            navigate('/login');
            return;
        }
        fetchTasks();
        checkApiStatus();
    }, [auth, auth?.loading, auth?.isAuthenticated]);

    const [apiStatus, setApiStatus] = useState<'online' | 'offline' | 'checking'>('checking');
    const [latency, setLatency] = useState<number | null>(null);

    const checkApiStatus = async () => {
        setApiStatus('checking');
        const start = Date.now();
        const url = 'http://localhost:8001/api/v1/health';
        try {
            await api.get(url); // Relative to /api/v1, so ../health hits /health
            // Actually, axios baseURL is /api/v1. Health is at root /health usually or /api/v1/health? 
            // Looking at main.py: @app.get("/health") is at root. 
            // So if baseURL is http://.../api/v1, we need to go up. 
            // Let's try absolute path if we can, or relative.
            // Since we can't easily know absolute, let's assume /health is at root.
            // But wait, axios baseURL includes /api/v1. 
            // Let's just use a direct fetch to the root health if possible or adjust path.
            // Actually main.py has: @app.get("/health") ... NOT inside a router.
            // So it is at http://localhost:8001/health.
            // Axios baseURL is http://localhost:8001/api/v1.
            // So we need to request '/../../health' ? No, that's messy.
            // Let's us a separate simple fetch request or 'axios.get' with full URL if we knew it.
            // For now, let's try assuming standard structure. 
            // Better yet, let's just make a new axios instance or use fetch.
        } catch (e) {
            // ignore
        }

        // Re-implementing with fetch to be safe about path
        try {
            // We can infer the base origin from the api.defaults.baseURL if strictly set, 
            // but here we know it runs on 8001.
            // Let's try to hit the health endpoint relative to the current window location if valid, 
            // but backend is on 8001...
            // Let's reuse 'api' but with specific path hack or just use fetch('http://localhost:8001/health').
            // Since we know the port is 8001 from context.
            const response = await fetch(url);
            const end = Date.now();
            setLatency(end - start);
            setApiStatus(response.ok ? 'online' : 'offline');
        } catch (err) {
            setApiStatus('offline');
            setLatency(null);
        }
    };

    const fetchTasks = async () => {
        try {
            const response = await api.get('/tasks/');
            setTasks(response.data);
        } catch (err) {
            console.error('Dashboard: Fetch failed', err);
        }
    };

    const handleCreateTask = async (e: React.FormEvent) => {
        e.preventDefault();
        try {
            await api.post('/tasks/', {
                title: newTaskTitle,
                description: newTaskDesc
            });
            setNewTaskTitle('');
            setNewTaskDesc('');
            showToast('Task created successfully', 'success');
            fetchTasks();
        } catch (err) {
            console.error('Dashboard: Create failed', err);
        }
    };

    const handleDeleteTask = async (taskId: string) => {
        try {
            await api.delete(`/tasks/${taskId}`);
            showToast('Task deleted successfully', 'success');
            fetchTasks();
        } catch (err) {
            console.error('Dashboard: Delete failed', err);
        }
    };

    const logout = () => {
        localStorage.removeItem('token');
        window.location.href = '/login';
    };

    return (
        <div className="container" style={{ paddingTop: '20px' }}>
            {/* Navigation Header */}
            <div className="glass-panel" style={{ padding: '15px 25px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontWeight: 'bold', fontSize: '1.2rem' }}>
                    <div style={{ background: 'rgba(255,255,255,0.2)', padding: '5px', borderRadius: '8px' }}>
                        <svg width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                        </svg>
                    </div>
                    Task Dashboard
                </div>
                <div style={{ display: 'flex', gap: '15px', alignItems: 'center' }}>
                    {auth?.user?.name}
                    {auth?.user?.role === 'ADMIN' && (
                        <button onClick={() => navigate('/admin')} className="glass-button" style={{ padding: '5px 12px', fontSize: '0.8rem', width: 'auto' }}>
                            Admin Panel
                        </button>
                    )}
                    <button onClick={logout} style={{ background: 'rgba(255,50,50,0.2)', border: '1px solid rgba(255,50,50,0.3)', color: '#ffcbcb', padding: '5px 12px', borderRadius: '6px', cursor: 'pointer' }}>
                        Sign Out
                    </button>
                </div>
            </div>

            <div className="grid grid-cols-3" style={{ marginBottom: '30px', gap: '20px' }}>
                <div className="glass-panel" style={{ padding: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                        <div style={{ fontSize: '0.9rem', opacity: 0.8, marginBottom: '5px' }}>System Status</div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                            <div style={{
                                width: '12px',
                                height: '12px',
                                borderRadius: '50%',
                                background: apiStatus === 'online' ? '#4ade80' : apiStatus === 'checking' ? '#fbbf24' : '#ef4444',
                                boxShadow: apiStatus === 'online' ? '0 0 8px #4ade80' : 'none'
                            }}></div>
                            <div style={{ fontSize: '1.2rem', fontWeight: 'bold' }}>
                                {apiStatus === 'online' ? 'Online' : apiStatus === 'checking' ? 'Checking...' : 'Offline'}
                            </div>
                        </div>
                        {latency !== null && (
                            <div style={{ fontSize: '0.8rem', opacity: 0.7, marginTop: '2px' }}>
                                Response time: <span style={{ color: latency < 200 ? '#86efac' : latency < 500 ? '#fde047' : '#fca5a5' }}>{latency}ms</span>
                            </div>
                        )}
                    </div>
                    <div style={{ background: 'rgba(59, 130, 246, 0.2)', padding: '10px', borderRadius: '10px', cursor: 'pointer' }} onClick={checkApiStatus} title="Refresh Status">
                        <svg width="30" height="30" fill="none" stroke="#60a5fa" viewBox="0 0 24 24" className={apiStatus === 'checking' ? 'spin' : ''}>
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                        </svg>
                    </div>
                </div>
                <div className="glass-panel" style={{ padding: '25px', marginBottom: '40px' }}>
                    <h3 style={{ marginTop: 0, marginBottom: '20px', fontSize: '1.3rem' }}>Create New Task</h3>
                    <form onSubmit={handleCreateTask} style={{ display: 'grid', gap: '15px', gridTemplateColumns: '1fr 2fr auto' }}>
                        <input
                            className="glass-input"
                            type="text"
                            placeholder="Task Title"
                            value={newTaskTitle}
                            onChange={(e) => setNewTaskTitle(e.target.value)}
                            required
                        />
                        <input
                            className="glass-input"
                            type="text"
                            placeholder="Description (optional)"
                            value={newTaskDesc}
                            onChange={(e) => setNewTaskDesc(e.target.value)}
                        />
                        <button type="submit" className="glass-button" style={{ width: 'auto', whiteSpace: 'nowrap' }}>
                            Add Task
                        </button>
                    </form>
                </div>

                <div style={{ marginBottom: '20px', borderBottom: '1px solid rgba(255,255,255,0.2)', paddingBottom: '10px' }}>
                    <h3 style={{ margin: 0, fontSize: '1.3rem' }}>My Tasks</h3>
                </div>

                {tasks.length === 0 ? (
                    <div className="glass-panel" style={{ textAlign: 'center', opacity: 0.7, padding: '40px' }}>
                        <p>No tasks found. Create one above!</p>
                    </div>
                ) : (
                    <div className="grid grid-cols-2" style={{ gap: '20px' }}>
                        {tasks.map(task => (
                            <div key={task._id} className="glass-panel" style={{ padding: '20px', display: 'flex', flexDirection: 'column', height: '100%', boxSizing: 'border-box' }}>
                                <div style={{ flex: 1 }}>
                                    <strong style={{ display: 'block', fontSize: '1.1rem', marginBottom: '5px' }}>{task.title}</strong>
                                    {task.description && <p style={{ margin: 0, opacity: 0.7, fontSize: '0.9rem', lineHeight: 1.5 }}>{task.description}</p>}
                                </div>
                                {(auth?.user?.role === 'ADMIN' || auth?.user?.sub === task.owner_id) && (
                                    <div style={{ marginTop: '15px', textAlign: 'right' }}>
                                        <button onClick={() => handleDeleteTask(task._id)} style={{ background: 'none', border: 'none', color: '#fca5a5', cursor: 'pointer', fontSize: '0.9rem' }}>Delete</button>
                                    </div>
                                )}
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
};

export default Dashboard;
