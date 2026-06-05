CREATE TABLE receipt_attachments (
    id BIGSERIAL PRIMARY KEY,
    lobby_id BIGINT NOT NULL REFERENCES lobbies(id),
    uploaded_by_user_id BIGINT NOT NULL REFERENCES users(id),
    receipt_image_url VARCHAR(500) NOT NULL,
    original_filename VARCHAR(255),
    content_type VARCHAR(100) NOT NULL,
    file_size_bytes BIGINT,
    checksum VARCHAR(128),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT receipt_attachments_status_check CHECK (status IN ('ACTIVE', 'REPLACED', 'DELETED'))
);

CREATE UNIQUE INDEX idx_receipt_attachments_one_active
ON receipt_attachments(lobby_id)
WHERE status = 'ACTIVE';

CREATE INDEX idx_receipt_attachments_lobby_created_at
ON receipt_attachments(lobby_id, created_at);
