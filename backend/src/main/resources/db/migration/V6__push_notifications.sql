CREATE TABLE device_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    device_token VARCHAR(500) NOT NULL UNIQUE,
    platform VARCHAR(20) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT device_tokens_platform_check CHECK (platform IN ('ANDROID', 'IOS', 'WEB'))
);

CREATE TABLE push_notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    lobby_id BIGINT REFERENCES lobbies(id),
    message_id BIGINT REFERENCES chat_messages(id),
    title VARCHAR(200) NOT NULL,
    body VARCHAR(500) NOT NULL,
    status VARCHAR(20) NOT NULL,
    error_message VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at TIMESTAMPTZ,
    CONSTRAINT push_notifications_status_check CHECK (status IN ('SENT', 'SKIPPED', 'FAILED'))
);

CREATE INDEX idx_device_tokens_user_enabled ON device_tokens(user_id, enabled);
CREATE INDEX idx_push_notifications_user_created_at ON push_notifications(user_id, created_at);
CREATE INDEX idx_push_notifications_lobby_message ON push_notifications(lobby_id, message_id);
