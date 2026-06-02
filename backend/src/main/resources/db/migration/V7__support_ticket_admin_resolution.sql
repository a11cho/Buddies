ALTER TABLE support_tickets
    ADD COLUMN resolution_note TEXT,
    ADD COLUMN resolved_by_admin_id BIGINT REFERENCES users(id),
    ADD COLUMN resolved_at TIMESTAMPTZ;

CREATE INDEX idx_support_tickets_status_created_at ON support_tickets(status, created_at);
