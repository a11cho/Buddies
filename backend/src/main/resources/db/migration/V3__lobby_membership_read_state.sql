ALTER TABLE lobby_memberships
    ADD COLUMN last_read_message_id BIGINT REFERENCES chat_messages(id),
    ADD COLUMN last_read_at TIMESTAMPTZ;

CREATE INDEX idx_lobby_memberships_read_state
ON lobby_memberships(lobby_id, user_id, last_read_message_id);
