import { useCallback, useEffect, useState } from 'react';
import { api } from '../api/client';

type Status = 'checking' | 'online' | 'offline';

export default function ServiceHealth() {
  const [status, setStatus] = useState<Status>('checking');
  const [latency, setLatency] = useState<number | null>(null);

  const checkHealth = useCallback(async () => {
    setStatus('checking');
    const started = performance.now();
    try {
      await api.get<{ status: string }>('/health');
      setLatency(Math.round(performance.now() - started));
      setStatus('online');
    } catch {
      setLatency(null);
      setStatus('offline');
    }
  }, []);

  useEffect(() => {
    void checkHealth();
  }, [checkHealth]);

  return (
    <button className="metric metric-button" type="button" onClick={checkHealth}>
      <span className={`status-dot status-${status}`} />
      <span>
        <span className="metric-label">Gateway</span>
        <strong>{status === 'checking' ? 'Checking' : status === 'online' ? 'Online' : 'Offline'}</strong>
        {latency !== null && <small>{latency} ms</small>}
      </span>
    </button>
  );
}
