import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import {
  ApiClient,
  ApiError,
  type ChatArchive,
  type ReportDetail,
  type ReportPage,
  type ReportSummary,
  type SystemOverview,
} from './apiClient';
import './styles.css';

const apiClient = new ApiClient();
const tokenStorageKey = 'buddies.admin.accessToken';

type View = 'overview' | 'reports' | 'archive';

function App() {
  const [token, setToken] = useState(() => localStorage.getItem(tokenStorageKey) ?? '');
  const [view, setView] = useState<View>('overview');
  const [overview, setOverview] = useState<SystemOverview | null>(null);
  const [reports, setReports] = useState<ReportPage | null>(null);
  const [selectedReport, setSelectedReport] = useState<ReportDetail | null>(null);
  const [archive, setArchive] = useState<ChatArchive | null>(null);
  const [status, setStatus] = useState('OPEN');
  const [archiveLobbyId, setArchiveLobbyId] = useState('');
  const [message, setMessage] = useState('');
  const authOptions = useMemo(() => ({ token }), [token]);

  useEffect(() => {
    if (!token) {
      return;
    }
    localStorage.setItem(tokenStorageKey, token);
    loadOverview();
    loadReports(status);
  }, [token]);

  async function loadOverview() {
    try {
      setOverview(await apiClient.getSystemOverview(authOptions));
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function loadReports(nextStatus = status) {
    try {
      const page = await apiClient.getReports(nextStatus, 1, 20, authOptions);
      setReports(page);
      if (page.items.length > 0) {
        await selectReport(page.items[0]);
      } else {
        setSelectedReport(null);
        setArchive(null);
      }
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function selectReport(report: ReportSummary) {
    try {
      const detail = await apiClient.getReport(report.reportId, authOptions);
      setSelectedReport(detail);
      setArchive(await apiClient.getChatArchive(detail.lobbyId, authOptions));
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function resolveSelectedReport() {
    if (!selectedReport) {
      return;
    }
    try {
      await apiClient.resolveReport(selectedReport.reportId, 'Resolved from admin review.', authOptions);
      setMessage(`Report #${selectedReport.reportId} resolved.`);
      await loadReports(status);
      await loadOverview();
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function loadArchiveByLobby() {
    const lobbyId = Number(archiveLobbyId);
    if (!Number.isFinite(lobbyId) || lobbyId <= 0) {
      setMessage('Enter a valid lobby ID.');
      return;
    }
    try {
      setArchive(await apiClient.getChatArchive(lobbyId, authOptions));
      setView('archive');
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  return (
    <main className="shell">
      <aside className="sidebar">
        <h1>Buddies Admin</h1>
        <nav>
          <button className={view === 'overview' ? 'active' : ''} onClick={() => setView('overview')}>Overview</button>
          <button className={view === 'reports' ? 'active' : ''} onClick={() => setView('reports')}>Reports</button>
          <button className={view === 'archive' ? 'active' : ''} onClick={() => setView('archive')}>Chat Archive</button>
        </nav>
      </aside>
      <section className="content">
        <header className="topbar">
          <div>
            <p>KAIST delivery coordination moderation</p>
            <h2>{viewLabel(view)}</h2>
          </div>
          <input
            aria-label="Admin access token"
            placeholder="Admin access token"
            value={token}
            onChange={(event) => setToken(event.target.value.trim())}
          />
        </header>

        {message && <div className="notice">{message}</div>}
        {!token && <div className="notice">Paste an ADMIN access token to load protected moderation data.</div>}

        {view === 'overview' && <Overview overview={overview} />}
        {view === 'reports' && (
          <Reports
            reports={reports}
            selectedReport={selectedReport}
            archive={archive}
            status={status}
            onStatusChange={(nextStatus) => {
              setStatus(nextStatus);
              loadReports(nextStatus);
            }}
            onSelect={selectReport}
            onResolve={resolveSelectedReport}
          />
        )}
        {view === 'archive' && (
          <ArchiveSearch
            lobbyId={archiveLobbyId}
            archive={archive}
            onLobbyIdChange={setArchiveLobbyId}
            onLoad={loadArchiveByLobby}
          />
        )}
      </section>
    </main>
  );
}

function Overview({ overview }: { overview: SystemOverview | null }) {
  return (
    <>
      <div className="metrics">
        <Metric label="Active Lobbies" value={overview?.activeLobbyCount} />
        <Metric label="Open Reports" value={overview?.openReportCount} />
        <Metric label="Active Users" value={overview?.activeUserCount} />
        <Metric label="Cart Locked" value={overview?.cartLockedLobbyCount} />
      </div>
      <section className="panel">
        <div className="panel-head">
          <h3>Recent Lobbies</h3>
        </div>
        <table>
          <thead>
            <tr>
              <th>Lobby</th>
              <th>Restaurant</th>
              <th>Location</th>
              <th>Members</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {(overview?.recentLobbies ?? []).map((lobby) => (
              <tr key={lobby.lobbyId}>
                <td>#{lobby.lobbyId}</td>
                <td>{lobby.restaurantName}</td>
                <td>{lobby.deliveryLocation}</td>
                <td>{lobby.participantCount}</td>
                <td><span className="status">{lobby.orderStatus}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  );
}

function Reports(props: {
  reports: ReportPage | null;
  selectedReport: ReportDetail | null;
  archive: ChatArchive | null;
  status: string;
  onStatusChange: (status: string) => void;
  onSelect: (report: ReportSummary) => void;
  onResolve: () => void;
}) {
  return (
    <div className="review-grid">
      <section className="panel">
        <div className="panel-head">
          <h3>Reports</h3>
          <select value={props.status} onChange={(event) => props.onStatusChange(event.target.value)}>
            <option value="OPEN">OPEN</option>
            <option value="IN_REVIEW">IN_REVIEW</option>
            <option value="RESOLVED">RESOLVED</option>
          </select>
        </div>
        <div className="report-list">
          {(props.reports?.items ?? []).map((report) => (
            <button
              key={report.reportId}
              className={props.selectedReport?.reportId === report.reportId ? 'report-row selected' : 'report-row'}
              onClick={() => props.onSelect(report)}
            >
              <strong>#{report.reportId}</strong>
              <span>Lobby {report.lobbyId}</span>
              <span>{report.reason}</span>
              <small>{formatDate(report.createdAt)}</small>
            </button>
          ))}
        </div>
      </section>
      <section className="panel detail">
        {props.selectedReport ? (
          <>
            <div className="panel-head">
              <h3>Report #{props.selectedReport.reportId}</h3>
              {props.selectedReport.status !== 'RESOLVED' && <button className="primary" onClick={props.onResolve}>Resolve</button>}
            </div>
            <dl>
              <dt>Reporter</dt>
              <dd>{props.selectedReport.reporter.name} ({props.selectedReport.reporter.id})</dd>
              <dt>Reported User</dt>
              <dd>{props.selectedReport.reportedUser.name} ({props.selectedReport.reportedUser.id})</dd>
              <dt>Reason</dt>
              <dd>{props.selectedReport.reason}</dd>
              <dt>Description</dt>
              <dd>{props.selectedReport.description ?? '-'}</dd>
              <dt>Reported Message</dt>
              <dd>{props.selectedReport.reportedMessageId ?? '-'}</dd>
            </dl>
            <ArchiveMessages archive={props.archive} />
          </>
        ) : (
          <p className="empty">No reports in this filter.</p>
        )}
      </section>
    </div>
  );
}

function ArchiveSearch(props: {
  lobbyId: string;
  archive: ChatArchive | null;
  onLobbyIdChange: (value: string) => void;
  onLoad: () => void;
}) {
  return (
    <section className="panel">
      <div className="search-row">
        <input
          aria-label="Lobby ID"
          placeholder="Lobby ID"
          value={props.lobbyId}
          onChange={(event) => props.onLobbyIdChange(event.target.value)}
        />
        <button className="primary" onClick={props.onLoad}>Load Archive</button>
      </div>
      <ArchiveMessages archive={props.archive} />
    </section>
  );
}

function ArchiveMessages({ archive }: { archive: ChatArchive | null }) {
  if (!archive) {
    return <p className="empty">No chat archive loaded.</p>;
  }
  return (
    <div className="messages">
      {archive.messages.map((message) => (
        <article key={message.messageId} className={message.reported ? 'message reported' : 'message'}>
          <div>
            <strong>{message.senderName ?? 'System'}</strong>
            <span>{message.senderUserId ? `User ${message.senderUserId}` : message.messageType}</span>
            <small>{formatDate(message.createdAt)}</small>
          </div>
          <p>{message.content ?? '-'}</p>
          {message.mediaUrl && <a href={message.mediaUrl}>Attachment</a>}
        </article>
      ))}
    </div>
  );
}

function Metric({ label, value }: { label: string; value?: number }) {
  return (
    <article>
      <span>{label}</span>
      <strong>{value ?? '-'}</strong>
    </article>
  );
}

function viewLabel(view: View) {
  return view === 'overview' ? 'System Overview' : view === 'reports' ? 'Report Review' : 'Chat Archive';
}

function formatDate(value?: string) {
  if (!value) {
    return '-';
  }
  return new Intl.DateTimeFormat('en', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

function errorMessage(error: unknown) {
  if (error instanceof ApiError) {
    return `${error.status}: ${error.message}`;
  }
  return error instanceof Error ? error.message : 'Unexpected error';
}

createRoot(document.getElementById('root')!).render(<App />);
