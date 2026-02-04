import React, { useState, useEffect, useContext } from 'react';
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
    const navigate = useNavigate();

    useEffect(() => {
        if (!auth?.isAuthenticated) {
            navigate('/login');
            return;
        }
        fetchTasks();
    }, [auth]);

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
            fetchTasks();
        } catch (err) {
            console.error('Dashboard: Create failed', err);
        }
    };

    const handleDeleteTask = async (taskId: string) => {
        try {
            await api.delete(`/tasks/${taskId}`);
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
                    <span style={{ fontSize: '0.9rem', opacity: 0.8 }}>
                        {auth?.user?.name || auth?.user?.sub}
                    </span>
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

            <div style={{ maxWidth: '800px', margin: '0 auto' }}>
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
