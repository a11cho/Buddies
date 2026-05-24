import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { ApiClient, type SystemOverview } from './apiClient';
import './styles.css';

const apiClient = new ApiClient();

function App() {
  const [overview, setOverview] = useState<SystemOverview | null>(null);

  useEffect(() => {
    apiClient
      .getSystemOverview()
      .then(setOverview)
      .catch(() =>
        setOverview({
          activeLobbyCount: 0,
          cartLockedLobbyCount: 0,
          activeUserCount: 0,
          openReportCount: 0,
          suspendedUserCount: 0,
          recentLobbies: [],
        }),
      );
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
            <strong>{overview?.activeLobbyCount ?? '-'}</strong>
          </article>
          <article>
            <span>Open Reports</span>
            <strong>{overview?.openReportCount ?? '-'}</strong>
          </article>
          <article>
            <span>Active Users</span>
            <strong>{overview?.activeUserCount ?? '-'}</strong>
          </article>
          <article>
            <span>Cart Locked</span>
            <strong>{overview?.cartLockedLobbyCount ?? '-'}</strong>
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
