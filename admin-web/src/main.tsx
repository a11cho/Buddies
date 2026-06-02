import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import {
  ApiClient,
  ApiError,
  type AdminUserDetail,
  type AdminUserPage,
  type AdminUserSummary,
  type ChatArchive,
  type CurrentUser,
  type ReportDetail,
  type ReportPage,
  type ReportSummary,
  type SupportTicketDetail,
  type SupportTicketPage,
  type SupportTicketSummary,
  type SystemOverview,
} from './apiClient';
import './styles.css';

const apiClient = new ApiClient();
const tokenStorageKey = 'buddies.admin.accessToken';

type View = 'overview' | 'reports' | 'tickets' | 'users' | 'archive';

function App() {
  const [token, setToken] = useState(() => localStorage.getItem(tokenStorageKey) ?? '');
  const [currentUser, setCurrentUser] = useState<CurrentUser | null>(null);
  const [view, setView] = useState<View>('overview');
  const [overview, setOverview] = useState<SystemOverview | null>(null);
  const [reports, setReports] = useState<ReportPage | null>(null);
  const [selectedReport, setSelectedReport] = useState<ReportDetail | null>(null);
  const [tickets, setTickets] = useState<SupportTicketPage | null>(null);
  const [selectedTicket, setSelectedTicket] = useState<SupportTicketDetail | null>(null);
  const [users, setUsers] = useState<AdminUserPage | null>(null);
  const [selectedUser, setSelectedUser] = useState<AdminUserDetail | null>(null);
  const [userStatus, setUserStatus] = useState('ACTIVE');
  const [archive, setArchive] = useState<ChatArchive | null>(null);
  const [status, setStatus] = useState('OPEN');
  const [ticketStatus, setTicketStatus] = useState('OPEN');
  const [archiveLobbyId, setArchiveLobbyId] = useState('');
  const [message, setMessage] = useState('');
  const [loginMessage, setLoginMessage] = useState('');
  const [isLoggingIn, setIsLoggingIn] = useState(false);
  const authOptions = useMemo(() => ({ token }), [token]);

  useEffect(() => {
    if (!token) {
      return;
    }
    localStorage.setItem(tokenStorageKey, token);
    verifySession(token);
  }, [token]);

  async function verifySession(nextToken: string) {
    try {
      const me = await apiClient.getMe({ token: nextToken });
      if (me.role !== 'ADMIN') {
        throw new ApiError(403, 'Admin role is required.');
      }
      setCurrentUser(me);
      setLoginMessage('');
      await loadOverview(nextToken);
      await loadReports(status, nextToken);
      await loadTickets(ticketStatus, nextToken);
      await loadUsers(userStatus, nextToken);
    } catch (error) {
      clearSession();
      setLoginMessage(errorMessage(error));
    }
  }

  async function login(email: string, password: string) {
    setIsLoggingIn(true);
    setLoginMessage('');
    try {
      const response = await apiClient.login(email, password);
      const me = await apiClient.getMe({ token: response.accessToken });
      if (me.role !== 'ADMIN') {
        throw new ApiError(403, 'Admin role is required.');
      }
      localStorage.setItem(tokenStorageKey, response.accessToken);
      setCurrentUser(me);
      setToken(response.accessToken);
      await loadOverview(response.accessToken);
      await loadReports(status, response.accessToken);
      await loadTickets(ticketStatus, response.accessToken);
      await loadUsers(userStatus, response.accessToken);
    } catch (error) {
      clearSession();
      setLoginMessage(errorMessage(error));
    } finally {
      setIsLoggingIn(false);
    }
  }

  function clearSession() {
    localStorage.removeItem(tokenStorageKey);
    setToken('');
    setCurrentUser(null);
    setOverview(null);
    setReports(null);
    setSelectedReport(null);
    setTickets(null);
    setSelectedTicket(null);
    setUsers(null);
    setSelectedUser(null);
    setArchive(null);
  }

  async function loadOverview(nextToken = token) {
    try {
      setOverview(await apiClient.getSystemOverview({ token: nextToken }));
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function loadReports(nextStatus = status, nextToken = token) {
    try {
      const page = await apiClient.getReports(nextStatus, 1, 20, { token: nextToken });
      setReports(page);
      if (page.items.length > 0) {
        await selectReport(page.items[0], nextToken);
      } else {
        setSelectedReport(null);
        setArchive(null);
      }
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function selectReport(report: ReportSummary, nextToken = token) {
    try {
      const detail = await apiClient.getReport(report.reportId, { token: nextToken });
      setSelectedReport(detail);
      setArchive(await apiClient.getChatArchive(detail.lobbyId, { token: nextToken }));
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function loadTickets(nextStatus = ticketStatus, nextToken = token) {
    try {
      const page = await apiClient.getSupportTickets(nextStatus, 1, 20, { token: nextToken });
      setTickets(page);
      if (page.items.length > 0) {
        await selectTicket(page.items[0], nextToken);
      } else {
        setSelectedTicket(null);
      }
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function selectTicket(ticket: SupportTicketSummary, nextToken = token) {
    try {
      setSelectedTicket(await apiClient.getSupportTicket(ticket.ticketId, { token: nextToken }));
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function updateSelectedTicket(nextStatus: string, resolutionNote: string) {
    if (!selectedTicket) {
      return;
    }
    try {
      await apiClient.updateSupportTicket(selectedTicket.ticketId, nextStatus, resolutionNote, authOptions);
      setMessage(`Support ticket #${selectedTicket.ticketId} updated.`);
      await loadTickets(ticketStatus);
      await loadOverview();
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function loadUsers(nextStatus = userStatus, nextToken = token) {
    try {
      const page = await apiClient.getUsers(nextStatus, 1, 20, { token: nextToken });
      setUsers(page);
      if (page.items.length > 0) {
        await selectUser(page.items[0], nextToken);
      } else {
        setSelectedUser(null);
      }
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function selectUser(user: AdminUserSummary, nextToken = token) {
    try {
      setSelectedUser(await apiClient.getUser(user.id, { token: nextToken }));
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function moderateSelectedUser(actionType: string, reason: string, endsAt: string | null, reportId: number | null) {
    if (!selectedUser) {
      return;
    }
    try {
      await apiClient.moderateUser(selectedUser.id, actionType, reason, endsAt, reportId, authOptions);
      setMessage(`${actionType} action applied to ${selectedUser.name}.`);
      await loadUsers(userStatus);
      await loadOverview();
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

  if (!token || !currentUser) {
    return <LoginScreen message={loginMessage} isLoading={isLoggingIn} onLogin={login} />;
  }

  return (
    <main className="shell">
      <aside className="sidebar">
        <h1>Buddies Admin</h1>
        <nav>
          <button className={view === 'overview' ? 'active' : ''} onClick={() => setView('overview')}>Overview</button>
          <button className={view === 'reports' ? 'active' : ''} onClick={() => setView('reports')}>Reports</button>
          <button className={view === 'tickets' ? 'active' : ''} onClick={() => setView('tickets')}>Tickets</button>
          <button className={view === 'users' ? 'active' : ''} onClick={() => setView('users')}>Users</button>
          <button className={view === 'archive' ? 'active' : ''} onClick={() => setView('archive')}>Chat Archive</button>
        </nav>
      </aside>
      <section className="content">
        <header className="topbar">
          <div>
            <p>KAIST delivery coordination moderation</p>
            <h2>{viewLabel(view)}</h2>
          </div>
          <div className="session-box">
            <span>{currentUser.name}</span>
            <small>{currentUser.email}</small>
            <button onClick={clearSession}>Logout</button>
          </div>
        </header>

        {message && <div className="notice">{message}</div>}

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
        {view === 'tickets' && (
          <Tickets
            tickets={tickets}
            selectedTicket={selectedTicket}
            status={ticketStatus}
            onStatusChange={(nextStatus) => {
              setTicketStatus(nextStatus);
              loadTickets(nextStatus);
            }}
            onSelect={selectTicket}
            onUpdate={updateSelectedTicket}
          />
        )}
        {view === 'users' && (
          <Users
            users={users}
            selectedUser={selectedUser}
            status={userStatus}
            onStatusChange={(nextStatus) => {
              setUserStatus(nextStatus);
              loadUsers(nextStatus);
            }}
            onSelect={selectUser}
            onModerate={moderateSelectedUser}
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

function LoginScreen(props: {
  message: string;
  isLoading: boolean;
  onLogin: (email: string, password: string) => void;
}) {
  const [email, setEmail] = useState('admin@kaist.ac.kr');
  const [password, setPassword] = useState('');

  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    props.onLogin(email.trim(), password);
  }

  return (
    <main className="login-shell">
      <section className="login-panel">
        <div>
          <p className="eyebrow">Buddies Admin</p>
          <h1>Sign in to moderation</h1>
        </div>
        <form onSubmit={submit}>
          <label>
            Email
            <input
              autoComplete="username"
              inputMode="email"
              placeholder="admin@kaist.ac.kr"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
            />
          </label>
          <label>
            Password
            <input
              autoComplete="current-password"
              placeholder="Password"
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
          </label>
          {props.message && <div className="login-error">{props.message}</div>}
          <button className="primary login-button" disabled={props.isLoading || !email || !password}>
            {props.isLoading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>
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
        <Metric label="Open Tickets" value={overview?.openSupportTicketCount} />
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

function Tickets(props: {
  tickets: SupportTicketPage | null;
  selectedTicket: SupportTicketDetail | null;
  status: string;
  onStatusChange: (status: string) => void;
  onSelect: (ticket: SupportTicketSummary) => void;
  onUpdate: (status: string, resolutionNote: string) => void;
}) {
  const [nextStatus, setNextStatus] = useState(props.selectedTicket?.status ?? 'IN_PROGRESS');
  const [resolutionNote, setResolutionNote] = useState(props.selectedTicket?.resolutionNote ?? '');

  useEffect(() => {
    setNextStatus(props.selectedTicket?.status === 'RESOLVED' ? 'RESOLVED' : 'IN_PROGRESS');
    setResolutionNote(props.selectedTicket?.resolutionNote ?? '');
  }, [props.selectedTicket?.ticketId, props.selectedTicket?.status, props.selectedTicket?.resolutionNote]);

  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    props.onUpdate(nextStatus, resolutionNote.trim());
  }

  return (
    <div className="review-grid">
      <section className="panel">
        <div className="panel-head">
          <h3>Support Tickets</h3>
          <select value={props.status} onChange={(event) => props.onStatusChange(event.target.value)}>
            <option value="OPEN">OPEN</option>
            <option value="IN_PROGRESS">IN_PROGRESS</option>
            <option value="RESOLVED">RESOLVED</option>
          </select>
        </div>
        <div className="report-list">
          {(props.tickets?.items ?? []).map((ticket) => (
            <button
              key={ticket.ticketId}
              className={props.selectedTicket?.ticketId === ticket.ticketId ? 'report-row selected' : 'report-row'}
              onClick={() => props.onSelect(ticket)}
            >
              <strong>#{ticket.ticketId} {ticket.title}</strong>
              <span>{ticket.category} - {ticket.userName}</span>
              <span>{ticket.lobbyId ? `Lobby ${ticket.lobbyId}` : 'No lobby linked'}</span>
              <small>{formatDate(ticket.createdAt)}</small>
            </button>
          ))}
        </div>
      </section>
      <section className="panel detail">
        {props.selectedTicket ? (
          <>
            <div className="panel-head">
              <h3>Ticket #{props.selectedTicket.ticketId}</h3>
              <span className="status">{props.selectedTicket.status}</span>
            </div>
            <dl>
              <dt>User</dt>
              <dd>{props.selectedTicket.user.name} ({props.selectedTicket.user.id})</dd>
              <dt>Lobby</dt>
              <dd>{props.selectedTicket.lobbyId ?? '-'}</dd>
              <dt>Category</dt>
              <dd>{props.selectedTicket.category}</dd>
              <dt>Title</dt>
              <dd>{props.selectedTicket.title}</dd>
              <dt>Created</dt>
              <dd>{formatDate(props.selectedTicket.createdAt)}</dd>
              <dt>Resolved By</dt>
              <dd>{props.selectedTicket.resolvedByAdmin ? `${props.selectedTicket.resolvedByAdmin.name} (${props.selectedTicket.resolvedByAdmin.id})` : '-'}</dd>
            </dl>
            <section className="ticket-body">
              <h3>Question</h3>
              <p>{props.selectedTicket.body}</p>
            </section>
            <form className="moderation-form" onSubmit={submit}>
              <div className="panel-head">
                <h3>Response</h3>
              </div>
              <label>
                Status
                <select value={nextStatus} onChange={(event) => setNextStatus(event.target.value)}>
                  <option value="OPEN">OPEN</option>
                  <option value="IN_PROGRESS">IN_PROGRESS</option>
                  <option value="RESOLVED">RESOLVED</option>
                </select>
              </label>
              <label>
                Resolution Note
                <textarea
                  required={nextStatus === 'RESOLVED'}
                  placeholder="Leave the handling note or final answer."
                  value={resolutionNote}
                  onChange={(event) => setResolutionNote(event.target.value)}
                />
              </label>
              <button className="primary" disabled={nextStatus === 'RESOLVED' && !resolutionNote.trim()}>
                Update Ticket
              </button>
            </form>
          </>
        ) : (
          <p className="empty">No support tickets in this filter.</p>
        )}
      </section>
    </div>
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

function Users(props: {
  users: AdminUserPage | null;
  selectedUser: AdminUserDetail | null;
  status: string;
  onStatusChange: (status: string) => void;
  onSelect: (user: AdminUserSummary) => void;
  onModerate: (actionType: string, reason: string, endsAt: string | null, reportId: number | null) => void;
}) {
  const [actionType, setActionType] = useState('WARNING');
  const [reason, setReason] = useState('');
  const [endsAt, setEndsAt] = useState('');
  const [reportId, setReportId] = useState('');

  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    props.onModerate(
      actionType,
      reason.trim(),
      actionType === 'SUSPEND' && endsAt ? new Date(endsAt).toISOString() : null,
      reportId ? Number(reportId) : null,
    );
    setReason('');
    setEndsAt('');
    setReportId('');
  }

  return (
    <div className="review-grid users-grid">
      <section className="panel">
        <div className="panel-head">
          <h3>Users</h3>
          <select value={props.status} onChange={(event) => props.onStatusChange(event.target.value)}>
            <option value="ACTIVE">ACTIVE</option>
            <option value="SUSPENDED">SUSPENDED</option>
            <option value="BANNED">BANNED</option>
          </select>
        </div>
        <div className="report-list">
          {(props.users?.items ?? []).map((user) => (
            <button
              key={user.id}
              className={props.selectedUser?.id === user.id ? 'report-row selected' : 'report-row'}
              onClick={() => props.onSelect(user)}
            >
              <strong>{user.name}</strong>
              <span>{user.email}</span>
              <span>{user.status} · Trust {user.trustScore.toFixed(2)}</span>
              <small>User {user.id} · {user.role}</small>
            </button>
          ))}
        </div>
      </section>
      <section className="panel detail">
        {props.selectedUser ? (
          <>
            <div className="panel-head">
              <h3>{props.selectedUser.name}</h3>
              <span className="status">{props.selectedUser.status}</span>
            </div>
            <div className="metrics compact">
              <Metric label="Reported" value={props.selectedUser.reportedCount} />
              <Metric label="Reporter" value={props.selectedUser.reporterCount} />
              <Metric label="Closed Lobbies" value={props.selectedUser.closedLobbyCount} />
              <Metric label="Trust Score" value={props.selectedUser.trustScore} />
            </div>
            <dl>
              <dt>Email</dt>
              <dd>{props.selectedUser.email}</dd>
              <dt>Role</dt>
              <dd>{props.selectedUser.role}</dd>
              <dt>Created</dt>
              <dd>{formatDate(props.selectedUser.createdAt)}</dd>
            </dl>
            <form className="moderation-form" onSubmit={submit}>
              <div className="panel-head">
                <h3>Moderation Action</h3>
              </div>
              <div className="form-grid">
                <label>
                  Action
                  <select value={actionType} onChange={(event) => setActionType(event.target.value)}>
                    <option value="WARNING">WARNING</option>
                    <option value="SUSPEND">SUSPEND</option>
                    <option value="BAN">BAN</option>
                    <option value="UNSUSPEND">UNSUSPEND</option>
                  </select>
                </label>
                <label>
                  Related Report
                  <input
                    min="1"
                    placeholder="Optional"
                    type="number"
                    value={reportId}
                    onChange={(event) => setReportId(event.target.value)}
                  />
                </label>
                {actionType === 'SUSPEND' && (
                  <label>
                    Ends At
                    <input
                      type="datetime-local"
                      value={endsAt}
                      onChange={(event) => setEndsAt(event.target.value)}
                    />
                  </label>
                )}
              </div>
              <label>
                Reason
                <textarea
                  required
                  placeholder="Describe why this action is being applied."
                  value={reason}
                  onChange={(event) => setReason(event.target.value)}
                />
              </label>
              <button className="primary" disabled={!reason.trim() || (actionType === 'SUSPEND' && !endsAt)}>
                Apply Action
              </button>
            </form>
            <section className="history-block">
              <h3>Moderation History</h3>
              <div className="messages">
                {props.selectedUser.moderationActions.length === 0 && <p className="empty">No moderation actions.</p>}
                {props.selectedUser.moderationActions.map((action) => (
                  <article key={action.id} className="message">
                    <div>
                      <strong>{action.actionType}</strong>
                      <span>{action.adminName}</span>
                      <small>{formatDate(action.createdAt)}</small>
                    </div>
                    <p>{action.reason}</p>
                    {action.reportId && <small>Report #{action.reportId}</small>}
                    {action.endsAt && <small>Ends {formatDate(action.endsAt)}</small>}
                  </article>
                ))}
              </div>
            </section>
          </>
        ) : (
          <p className="empty">No users in this filter.</p>
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
  return view === 'overview'
    ? 'System Overview'
    : view === 'reports'
      ? 'Report Review'
      : view === 'tickets'
        ? 'Support Tickets'
        : view === 'users'
          ? 'User Management'
          : 'Chat Archive';
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
