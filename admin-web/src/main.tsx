import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

type Overview = {
  activeLobbies: number;
  openReports: number;
  activeUsers: number;
};

function App() {
  const [overview, setOverview] = useState<Overview | null>(null);

  useEffect(() => {
    fetch('/api/admin/system/overview')
      .then((response) => response.json())
      .then(setOverview)
      .catch(() => setOverview({ activeLobbies: 0, openReports: 0, activeUsers: 0 }));
  }, []);

  return (
    <main className="shell">
      <aside className="sidebar">
        <h1>Buddies Admin</h1>
        <nav>
          <button className="active">Overview</button>
          <button>Reports</button>
          <button>Chat Archive</button>
          <button>Users</button>
          <button>Audit Logs</button>
        </nav>
      </aside>
      <section className="content">
        <header>
          <p>KAIST delivery coordination moderation</p>
          <h2>System Overview</h2>
        </header>
        <div className="metrics">
          <article>
            <span>Active Lobbies</span>
            <strong>{overview?.activeLobbies ?? '-'}</strong>
          </article>
          <article>
            <span>Open Reports</span>
            <strong>{overview?.openReports ?? '-'}</strong>
          </article>
          <article>
            <span>Active Users</span>
            <strong>{overview?.activeUsers ?? '-'}</strong>
          </article>
        </div>
        <section className="panel">
          <h3>Next Implementation Targets</h3>
          <ul>
            <li>Connect Admin RBAC and JWT storage.</li>
            <li>Implement report list and archive viewer.</li>
            <li>Add user moderation actions with audit logs.</li>
          </ul>
        </section>
      </section>
    </main>
  );
}

createRoot(document.getElementById('root')!).render(<App />);

