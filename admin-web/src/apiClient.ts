export type SystemOverview = {
  activeLobbyCount: number;
  cartLockedLobbyCount: number;
  activeUserCount: number;
  openReportCount: number;
  suspendedUserCount: number;
  recentLobbies: RecentLobby[];
};

export type ReportPage = {
  items: ReportSummary[];
  page: number;
  size: number;
  totalCount: number;
};

export type ReportSummary = {
  reportId: number;
  lobbyId: number;
  reporterUserId: number;
  reportedUserId: number;
  reason: string;
  status: string;
  createdAt: string;
};

export type ReportDetail = {
  reportId: number;
  lobbyId: number;
  reporter: UserReference;
  reportedUser: UserReference;
  reportedMessageId: number | null;
  reason: string;
  description: string | null;
  status: string;
  resolutionNote: string | null;
  createdAt: string;
};

export type UserReference = {
  id: number;
  name: string;
};

export type ChatArchive = {
  lobbyId: number;
  messages: ArchiveMessage[];
};

export type ArchiveMessage = {
  messageId: number;
  lobbyId: number;
  senderUserId: number | null;
  senderName: string | null;
  messageType: string;
  content: string | null;
  mediaUrl: string | null;
  reported: boolean;
  createdAt: string;
};

export type RecentLobby = {
  lobbyId: number;
  restaurantName: string;
  deliveryLocation: string;
  hostUserId: number;
  participantCount: number;
  currentTotal: number;
  orderStatus: string;
  cartLocked: boolean;
  createdAt: string;
};

export type CurrentUser = {
  id: number;
  email: string;
  name: string;
  role: string;
};

type RequestOptions = {
  token?: string;
  query?: Record<string, string | number | boolean | undefined>;
};

type RequestBody = Record<string, unknown>;

export class ApiClient {
  constructor(private readonly baseUrl = '/api') {
    this.assertSecureBaseUrl(baseUrl);
  }

  async getSystemOverview(options: RequestOptions = {}): Promise<SystemOverview> {
    return this.request<SystemOverview>('/admin/system/overview', options);
  }

  async getReports(status = 'OPEN', page = 1, size = 20, options: RequestOptions = {}): Promise<ReportPage> {
    return this.request<ReportPage>('/admin/reports', {
      ...options,
      query: { status, page, size },
    });
  }

  async getReport(reportId: number, options: RequestOptions = {}): Promise<ReportDetail> {
    return this.request<ReportDetail>(`/admin/reports/${reportId}`, options);
  }

  async resolveReport(reportId: number, resolutionNote: string, options: RequestOptions = {}): Promise<MessageResponse> {
    return this.request<MessageResponse>(`/admin/reports/${reportId}/resolve`, {
      ...options,
      method: 'PATCH',
      body: { resolutionNote },
    });
  }

  async getChatArchive(lobbyId: number, options: RequestOptions = {}): Promise<ChatArchive> {
    return this.request<ChatArchive>(`/admin/lobbies/${lobbyId}/chat-archive`, options);
  }

  async login(email: string, password: string): Promise<LoginResponse> {
    // Passwords are sent only over HTTPS/TLS and must be bcrypt-verified by the server.
    return this.request<LoginResponse>('/auth/login', {
      method: 'POST',
      body: { email, password },
    });
  }

  async getMe(options: RequestOptions = {}): Promise<CurrentUser> {
    return this.request<CurrentUser>('/auth/me', options);
  }

  async verifySignup(email: string, otp: string): Promise<MessageResponse> {
    return this.request<MessageResponse>('/auth/signup/verify', {
      method: 'POST',
      body: { email, otp: await sha256Hex(otp) },
    });
  }

  async confirmPasswordReset(token: string, newPassword: string, newPasswordConfirm: string): Promise<MessageResponse> {
    return this.request<MessageResponse>('/auth/password-reset/confirm', {
      method: 'POST',
      body: {
        token: await sha256Hex(token),
        newPassword,
        newPasswordConfirm,
      },
    });
  }

  private async request<T>(
    path: string,
    options: RequestOptions & { method?: string; body?: RequestBody } = {},
  ): Promise<T> {
    const response = await fetch(this.buildUrl(path, options.query), {
      method: options.method ?? 'GET',
      headers: this.headers(options.token),
      body: options.body ? JSON.stringify(options.body) : undefined,
      cache: 'no-store',
      credentials: 'same-origin',
    });

    if (!response.ok) {
      throw new ApiError(response.status, await this.errorMessage(response));
    }

    return response.json() as Promise<T>;
  }

  private buildUrl(path: string, query?: RequestOptions['query']) {
    const url = new URL(`${this.baseUrl}${path}`, window.location.origin);
    Object.entries(query ?? {}).forEach(([key, value]) => {
      if (value !== undefined) {
        url.searchParams.set(key, String(value));
      }
    });
    return url;
  }

  private headers(token?: string) {
    const headers = new Headers({
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    });
    if (token) {
      headers.set('Authorization', `Bearer ${token}`);
    }
    return headers;
  }

  private async errorMessage(response: Response) {
    try {
      const body = await response.json();
      return body.message ?? body.error ?? response.statusText;
    } catch {
      return response.statusText;
    }
  }

  private assertSecureBaseUrl(baseUrl: string) {
    const url = new URL(baseUrl, window.location.origin);
    const isLocalhost = ['localhost', '127.0.0.1', '::1'].includes(url.hostname);
    if (url.protocol !== 'https:' && !isLocalhost) {
      throw new Error('Buddies API requires HTTPS for non-local network communication.');
    }
  }
}

export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export type LoginResponse = {
  accessToken: string;
  tokenType: 'Bearer';
  expiresIn: number;
};

export type MessageResponse = {
  message: string;
};

export async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}
