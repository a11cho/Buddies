CREATE EXTENSION IF NOT EXISTS postgis;

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

CREATE TABLE delivery_zones (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL UNIQUE,
    boundary GEOGRAPHY(POLYGON, 4326),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE lobbies (
    id BIGSERIAL PRIMARY KEY,
    host_user_id BIGINT NOT NULL REFERENCES users(id),
    delivery_zone_id BIGINT NOT NULL REFERENCES delivery_zones(id),
    restaurant_name VARCHAR(200) NOT NULL,
    minimum_order_amount BIGINT NOT NULL,
    delivery_fee_amount BIGINT NOT NULL DEFAULT 0,
    current_total_amount BIGINT NOT NULL DEFAULT 0,
    status VARCHAR(40) NOT NULL DEFAULT 'WAITING',
    cart_locked_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT lobbies_status_check CHECK (status IN ('WAITING', 'ORDER_PLACED', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED'))
);

CREATE TABLE lobby_memberships (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    role VARCHAR(20) NOT NULL DEFAULT 'PARTICIPANT',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    left_at TIMESTAMPTZ,
    UNIQUE (lobby_id, user_id),
    CONSTRAINT lobby_memberships_role_check CHECK (role IN ('HOST', 'PARTICIPANT')),
    CONSTRAINT lobby_memberships_status_check CHECK (status IN ('ACTIVE', 'LEFT', 'KICKED'))
);

CREATE TABLE cart_items (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    owner_user_id BIGINT NOT NULL REFERENCES users(id),
    name VARCHAR(200) NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price BIGINT NOT NULL,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE payment_records (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    food_amount BIGINT NOT NULL DEFAULT 0,
    delivery_fee_share_amount BIGINT NOT NULL DEFAULT 0,
    total_amount BIGINT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'UNPAID',
    paid_confirmed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (lobby_id, user_id),
    CONSTRAINT payment_records_status_check CHECK (status IN ('UNPAID', 'PAID'))
);

CREATE TABLE chat_messages (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    sender_user_id BIGINT REFERENCES users(id),
    type VARCHAR(20) NOT NULL,
    body VARCHAR(500),
    media_url VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chat_messages_type_check CHECK (type IN ('USER', 'SYSTEM', 'MEDIA'))
);

CREATE TABLE chat_archives (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    archived_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE reports (
    id BIGSERIAL PRIMARY KEY,
    reporter_user_id BIGINT NOT NULL REFERENCES users(id),
    reported_user_id BIGINT NOT NULL REFERENCES users(id),
    lobby_id BIGINT REFERENCES lobbies(id),
    chat_message_id BIGINT REFERENCES chat_messages(id),
    reason VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    resolution_note TEXT,
    resolved_by_admin_id BIGINT REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT reports_status_check CHECK (status IN ('OPEN', 'UNDER_REVIEW', 'RESOLVED'))
);

CREATE TABLE ratings (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    rater_user_id BIGINT NOT NULL REFERENCES users(id),
    target_user_id BIGINT NOT NULL REFERENCES users(id),
    score INTEGER NOT NULL,
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (lobby_id, rater_user_id, target_user_id),
    CONSTRAINT ratings_score_check CHECK (score BETWEEN 1 AND 5)
);

CREATE TABLE support_tickets (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    lobby_id BIGINT REFERENCES lobbies(id),
    subject VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE moderation_actions (
    id BIGSERIAL PRIMARY KEY,
    target_user_id BIGINT NOT NULL REFERENCES users(id),
    admin_user_id BIGINT NOT NULL REFERENCES users(id),
    report_id BIGINT REFERENCES reports(id),
    action_type VARCHAR(30) NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE admin_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    admin_user_id BIGINT NOT NULL REFERENCES users(id),
    action VARCHAR(120) NOT NULL,
    target_type VARCHAR(60) NOT NULL,
    target_id BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_lobbies_status_zone_locked ON lobbies(status, delivery_zone_id, cart_locked_at);
CREATE INDEX idx_lobbies_created_at ON lobbies(created_at);
CREATE INDEX idx_lobby_memberships_user_status ON lobby_memberships(user_id, status);
CREATE INDEX idx_lobby_memberships_lobby_status ON lobby_memberships(lobby_id, status);
CREATE INDEX idx_cart_items_lobby_owner_deleted ON cart_items(lobby_id, owner_user_id, deleted_at);
CREATE INDEX idx_payment_records_lobby_user ON payment_records(lobby_id, user_id);
CREATE INDEX idx_chat_messages_lobby_created ON chat_messages(lobby_id, created_at);
CREATE INDEX idx_reports_status_created ON reports(status, created_at);
CREATE INDEX idx_reports_lobby ON reports(lobby_id);
CREATE INDEX idx_ratings_unique_lookup ON ratings(lobby_id, rater_user_id, target_user_id);
CREATE INDEX idx_admin_audit_logs_admin_created ON admin_audit_logs(admin_user_id, created_at);

