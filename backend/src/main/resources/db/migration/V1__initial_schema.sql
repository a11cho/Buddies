CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'USER',
    profile_image_url VARCHAR(500),
    trust_score NUMERIC(3,2) NOT NULL DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    suspended_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT users_role_check CHECK (role IN ('USER', 'ADMIN')),
    CONSTRAINT users_status_check CHECK (status IN ('ACTIVE', 'SUSPENDED', 'BANNED'))
);

CREATE TABLE pending_signups (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    otp_hash VARCHAR(255) NOT NULL,
    otp_expires_at TIMESTAMPTZ NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    resend_available_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE password_reset_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE lobbies (
    id BIGSERIAL PRIMARY KEY,
    host_user_id BIGINT NOT NULL REFERENCES users(id),
    restaurant_name VARCHAR(200) NOT NULL,
    delivery_location VARCHAR(100) NOT NULL,
    minimum_order_amount BIGINT NOT NULL,
    current_total_amount BIGINT NOT NULL DEFAULT 0,
    delivery_fee BIGINT NOT NULL DEFAULT 0,
    host_bank_account VARCHAR(255),
    toss_deep_link VARCHAR(500),
    kakao_pay_deep_link VARCHAR(500),
    order_status VARCHAR(40) NOT NULL DEFAULT 'WAITING',
    cart_locked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT lobbies_order_status_check CHECK (
        order_status IN ('WAITING', 'LOCKED', 'ORDER_PLACED', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CLOSED', 'CANCELED')
    )
);

CREATE TABLE lobby_memberships (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    role_in_lobby VARCHAR(20) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    left_at TIMESTAMPTZ,
    CONSTRAINT lobby_memberships_role_check CHECK (role_in_lobby IN ('HOST', 'PARTICIPANT')),
    CONSTRAINT lobby_memberships_status_check CHECK (status IN ('ACTIVE', 'LEFT', 'KICKED', 'REMOVED_BY_TRANSFER'))
);

CREATE TABLE cart_items (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    owner_user_id BIGINT NOT NULL REFERENCES users(id),
    menu_name VARCHAR(200) NOT NULL,
    unit_price BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    subtotal BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
    -- TODO: SRS deletion wording and settlement evidence retention need a final team decision.
);

CREATE TABLE payment_records (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    amount BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'UNPAID',
    confirmed_by_host_id BIGINT REFERENCES users(id),
    confirmed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT payment_records_status_check CHECK (status IN ('UNPAID', 'PAID', 'INACTIVE'))
);

CREATE TABLE chat_messages (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    sender_user_id BIGINT REFERENCES users(id),
    message_type VARCHAR(20) NOT NULL,
    content VARCHAR(500),
    media_url VARCHAR(500),
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chat_messages_type_check CHECK (message_type IN ('USER', 'SYSTEM', 'MEDIA'))
    -- TODO: Restricted Korean/English keyword policy is not finalized yet.
);

CREATE TABLE chat_memberships (
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_read_message_id BIGINT REFERENCES chat_messages(id),
    PRIMARY KEY (lobby_id, user_id)
);

CREATE TABLE chat_archives (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    archived_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    retention_until TIMESTAMPTZ NOT NULL
);

CREATE TABLE ratings (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    rater_user_id BIGINT NOT NULL REFERENCES users(id),
    target_user_id BIGINT NOT NULL REFERENCES users(id),
    rating INTEGER NOT NULL,
    feedback TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (lobby_id, rater_user_id, target_user_id),
    CONSTRAINT ratings_rating_check CHECK (rating BETWEEN 1 AND 5)
);

CREATE TABLE support_tickets (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    lobby_id BIGINT REFERENCES lobbies(id),
    category VARCHAR(100) NOT NULL,
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT support_tickets_status_check CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED'))
);

CREATE TABLE reports (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    reporter_user_id BIGINT NOT NULL REFERENCES users(id),
    reported_user_id BIGINT NOT NULL REFERENCES users(id),
    reported_message_id BIGINT REFERENCES chat_messages(id),
    reason VARCHAR(100) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    resolution_note TEXT,
    resolved_by_admin_id BIGINT REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT reports_status_check CHECK (status IN ('OPEN', 'IN_REVIEW', 'RESOLVED'))
);

CREATE TABLE moderation_actions (
    id BIGSERIAL PRIMARY KEY,
    target_user_id BIGINT NOT NULL REFERENCES users(id),
    admin_user_id BIGINT NOT NULL REFERENCES users(id),
    report_id BIGINT REFERENCES reports(id),
    action_type VARCHAR(30) NOT NULL,
    reason TEXT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT moderation_actions_type_check CHECK (action_type IN ('WARNING', 'SUSPEND', 'BAN', 'UNSUSPEND'))
);

CREATE TABLE admin_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    admin_user_id BIGINT NOT NULL REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(50) NOT NULL,
    target_id BIGINT NOT NULL,
    metadata_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- TODO: Refresh-token/logout invalidation storage is still under discussion.
CREATE UNIQUE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status_created_at ON users(status, created_at);
CREATE UNIQUE INDEX idx_pending_signups_email ON pending_signups(email);
CREATE UNIQUE INDEX idx_password_reset_tokens_hash ON password_reset_tokens(token_hash);
CREATE INDEX idx_lobbies_search ON lobbies(delivery_location, restaurant_name, order_status, cart_locked_at);
CREATE INDEX idx_lobby_memberships_user_status ON lobby_memberships(user_id, status);
CREATE INDEX idx_lobby_memberships_lobby_status ON lobby_memberships(lobby_id, status);
CREATE INDEX idx_cart_items_lobby_owner ON cart_items(lobby_id, owner_user_id, deleted_at);
CREATE UNIQUE INDEX idx_payment_records_lobby_user ON payment_records(lobby_id, user_id);
CREATE INDEX idx_chat_messages_lobby_created_at ON chat_messages(lobby_id, created_at);
CREATE UNIQUE INDEX idx_ratings_unique ON ratings(lobby_id, rater_user_id, target_user_id);
CREATE INDEX idx_reports_status_created_at ON reports(status, created_at);
CREATE INDEX idx_reports_lobby_id ON reports(lobby_id);
CREATE INDEX idx_reports_reported_status ON reports(reported_user_id, status);
CREATE INDEX idx_moderation_actions_target_user_id ON moderation_actions(target_user_id);
CREATE INDEX idx_moderation_actions_target_created_at ON moderation_actions(target_user_id, created_at);
CREATE INDEX idx_admin_audit_logs_admin_created_at ON admin_audit_logs(admin_user_id, created_at);
