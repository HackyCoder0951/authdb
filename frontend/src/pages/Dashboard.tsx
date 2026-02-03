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

    return (
        <div style={{ padding: '20px' }}>
            <h1>Dashboard</h1>
            <p>Welcome, {auth?.user?.sub}</p>
            <button onClick={auth?.logout} style={{ marginBottom: '20px' }}>Logout</button>

            <div style={{ marginBottom: '30px' }}>
                <h3>Create New Task</h3>
                <form onSubmit={handleCreateTask}>
                    <input
                        type="text"
                        placeholder="Title"
                        value={newTaskTitle}
                        onChange={(e) => setNewTaskTitle(e.target.value)}
                        required
                        style={{ marginRight: '10px' }}
                    />
                    <input
                        type="text"
                        placeholder="Description"
                        value={newTaskDesc}
                        onChange={(e) => setNewTaskDesc(e.target.value)}
                        style={{ marginRight: '10px' }}
                    />
                    <button type="submit">Add Task</button>
                </form>
            </div>

            <h3>My Tasks</h3>
            <ul>
                {tasks.map(task => (
                    <li key={task._id} style={{ marginBottom: '10px', border: '1px solid #ccc', padding: '10px' }}>
                        <strong>{task.title}</strong>
                        {task.description && <p>{task.description}</p>}
                        {(auth?.user?.role === 'ADMIN' || auth?.user?.sub === task.owner_id) && (
                            <button onClick={() => handleDeleteTask(task._id)} style={{ backgroundColor: 'red', color: 'white', marginTop: '5px' }}>Delete</button>
                        )}
                    </li>
                ))}
            </ul>
        </div>
    );
};

export default Dashboard;
