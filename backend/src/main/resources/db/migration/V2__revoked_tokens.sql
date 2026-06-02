CREATE TABLE revoked_tokens (
    id BIGSERIAL PRIMARY KEY,
    token_id VARCHAR(36) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_revoked_tokens_token_id ON revoked_tokens(token_id);
CREATE INDEX idx_revoked_tokens_expires_at ON revoked_tokens(expires_at);
