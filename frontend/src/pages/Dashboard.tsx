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
        console.log('Dashboard: Fetching tasks...');
        try {
            const response = await api.get('/tasks/');
            console.log('Dashboard: Tasks fetched', response.data);
            setTasks(response.data);
        } catch (err) {
            console.error('Dashboard: Fetch failed', err);
        }
    };

    const handleCreateTask = async (e: React.FormEvent) => {
        e.preventDefault();
        console.log('Dashboard: Creating task', newTaskTitle);
        try {
            await api.post('/tasks/', {
                title: newTaskTitle,
                description: newTaskDesc
            });
            console.log('Dashboard: Task created');
            setNewTaskTitle('');
            setNewTaskDesc('');
            fetchTasks();
        } catch (err) {
            console.error('Dashboard: Create failed', err);
        }
    };

    const handleDeleteTask = async (taskId: string) => {
        console.log('Dashboard: Deleting task', taskId);
        try {
            await api.delete(`/tasks/${taskId}`);
            console.log('Dashboard: Task deleted');
            fetchTasks();
        } catch (err) {
            console.error('Dashboard: Delete failed', err);
        }
    };

    const [showName, setShowName] = useState(true);

    return (
        <div style={{ maxWidth: '800px', margin: '0 auto', padding: '20px', fontFamily: 'sans-serif' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' }}>
                <h1 style={{ margin: 0, color: '#333' }}>Task Dashboard</h1>
                <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                    <div style={{ marginRight: '15px' }}>
                        <span style={{ marginRight: '10px', color: '#666' }}>
                            Welcome, <strong>{showName ? (auth?.user?.name || auth?.user?.sub) : auth?.user?.sub}</strong>
                        </span>
                        <label style={{ fontSize: '12px', cursor: 'pointer', userSelect: 'none' }}>
                            <input
                                type="checkbox"
                                checked={showName}
                                onChange={(e) => setShowName(e.target.checked)}
                                style={{ marginRight: '5px' }}
                            />
                            Show Name
                        </label>
                    </div>
                    {auth?.user?.role === 'ADMIN' && (
                        <button onClick={() => navigate('/admin')} style={{ padding: '8px 16px', background: '#10b981', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer', fontSize: '14px' }}>Admin Panel</button>
                    )}
                    <button onClick={auth?.logout} style={{ padding: '8px 16px', background: '#ef4444', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer', fontSize: '14px' }}>Logout</button>
                </div>
            </div>

            <div style={{ background: '#f9fafb', padding: '20px', borderRadius: '8px', marginBottom: '30px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)' }}>
                <h3 style={{ marginTop: 0, marginBottom: '15px', color: '#374151' }}>Create New Task</h3>
                <form onSubmit={handleCreateTask} style={{ display: 'flex', gap: '10px' }}>
                    <input
                        type="text"
                        placeholder="Task Title"
                        value={newTaskTitle}
                        onChange={(e) => setNewTaskTitle(e.target.value)}
                        required
                        style={{ flex: 1, padding: '10px', borderRadius: '6px', border: '1px solid #d1d5db' }}
                    />
                    <input
                        type="text"
                        placeholder="Description (optional)"
                        value={newTaskDesc}
                        onChange={(e) => setNewTaskDesc(e.target.value)}
                        style={{ flex: 2, padding: '10px', borderRadius: '6px', border: '1px solid #d1d5db' }}
                    />
                    <button type="submit" style={{ padding: '10px 20px', background: '#3b82f6', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer', fontWeight: 'bold' }}>Add</button>
                </form>
            </div>

            <h3 style={{ color: '#374151', paddingBottom: '10px', borderBottom: '2px solid #e5e7eb' }}>My Tasks</h3>
            {tasks.length === 0 ? (
                <p style={{ color: '#6b7280', textAlign: 'center', marginTop: '20px' }}>No tasks found. Create one above!</p>
            ) : (
                <ul style={{ listStyle: 'none', padding: 0, display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))', gap: '20px' }}>
                    {tasks.map(task => (
                        <li key={task._id} style={{ background: 'white', border: '1px solid #e5e7eb', borderRadius: '8px', padding: '15px', boxShadow: '0 1px 2px rgba(0,0,0,0.05)', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
                            <div>
                                <strong style={{ display: 'block', fontSize: '18px', marginBottom: '5px', color: '#111827' }}>{task.title}</strong>
                                {task.description && <p style={{ margin: 0, color: '#6b7280', fontSize: '14px', lineHeight: '1.4' }}>{task.description}</p>}
                            </div>
                            {(auth?.user?.role === 'ADMIN' || auth?.user?.sub === task.owner_id) && (
                                <button onClick={() => handleDeleteTask(task._id)} style={{ alignSelf: 'flex-end', marginTop: '15px', background: 'transparent', color: '#ef4444', border: 'none', cursor: 'pointer', fontSize: '14px', padding: '0' }}>Delete Task</button>
                            )}
                        </li>
                    ))}
                </ul>
            )}
        </div>
    );
};

export default Dashboard;
