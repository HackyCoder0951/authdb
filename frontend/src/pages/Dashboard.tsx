import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import AppShell from '../components/AppShell';
import ServiceHealth from '../components/ServiceHealth';
import { api } from '../api/client';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';

type Task = {
  _id?: string;
  id?: string;
  title: string;
  description?: string | null;
  owner_id: string;
  created_at?: string;
};

function taskId(task: Task) {
  return task._id ?? task.id ?? '';
}

export default function Dashboard() {
  const { user } = useAuth();
  const { showToast } = useToast();
  const [tasks, setTasks] = useState<Task[]>([]);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(true);
  const [editingId, setEditingId] = useState<string | null>(null);

  const loadTasks = useCallback(async () => {
    setLoading(true);
    try {
      const response = await api.get<Task[]>('/tasks/');
      setTasks(response);
    } catch (error) {
      showToast(error instanceof Error ? error.message : 'Could not load tasks', 'error');
    } finally {
      setLoading(false);
    }
  }, [showToast]);

  useEffect(() => {
    void loadTasks();
  }, [loadTasks]);

  const completedLabel = useMemo(() => `${tasks.length} task${tasks.length === 1 ? '' : 's'}`, [tasks.length]);

  const resetForm = () => {
    setTitle('');
    setDescription('');
    setEditingId(null);
  };

  const submitTask = async (event: FormEvent) => {
    event.preventDefault();
    try {
      const payload = { title, description: description || undefined };
      if (editingId) {
        await api.put(`/tasks/${editingId}`, payload);
        showToast('Task updated', 'success');
      } else {
        await api.post('/tasks/', payload);
        showToast('Task created', 'success');
      }
      resetForm();
      await loadTasks();
    } catch (error) {
      showToast(error instanceof Error ? error.message : 'Could not save task', 'error');
    }
  };

  const deleteTask = async (id: string) => {
    try {
      await api.delete(`/tasks/${id}`);
      showToast('Task deleted', 'success');
      await loadTasks();
    } catch (error) {
      showToast(error instanceof Error ? error.message : 'Could not delete task', 'error');
    }
  };

  const startEdit = (task: Task) => {
    setEditingId(taskId(task));
    setTitle(task.title);
    setDescription(task.description ?? '');
  };

  return (
    <AppShell>
      <section className="page-head">
        <div>
          <p className="eyebrow">Task workspace</p>
          <h1>My tasks</h1>
        </div>
        <div className="metric-row">
          <div className="metric">
            <span className="metric-label">Current list</span>
            <strong>{completedLabel}</strong>
          </div>
          <ServiceHealth />
        </div>
      </section>

      <section className="panel">
        <form className="task-form" onSubmit={submitTask}>
          <label>
            Title
            <input value={title} onChange={(event) => setTitle(event.target.value)} required />
          </label>
          <label>
            Description
            <input value={description} onChange={(event) => setDescription(event.target.value)} />
          </label>
          <button className="button button-primary" type="submit">
            {editingId ? 'Update task' : 'Add task'}
          </button>
          {editingId && (
            <button className="button button-muted" type="button" onClick={resetForm}>
              Cancel
            </button>
          )}
        </form>
      </section>

      <section className="task-grid">
        {loading ? (
          <div className="empty-state">Loading tasks</div>
        ) : tasks.length === 0 ? (
          <div className="empty-state">No tasks yet.</div>
        ) : (
          tasks.map((task) => {
            const id = taskId(task);
            const canEdit = user?.role === 'ADMIN' || user?.sub === task.owner_id;
            return (
              <article className="task-card" key={id}>
                <div>
                  <h2>{task.title}</h2>
                  <p>{task.description || 'No description'}</p>
                </div>
                <div className="card-actions">
                  {canEdit && (
                    <button className="button button-muted" type="button" onClick={() => startEdit(task)}>
                      Edit
                    </button>
                  )}
                  {canEdit && (
                    <button className="button button-danger" type="button" onClick={() => void deleteTask(id)}>
                      Delete
                    </button>
                  )}
                </div>
              </article>
            );
          })
        )}
      </section>
    </AppShell>
  );
}
