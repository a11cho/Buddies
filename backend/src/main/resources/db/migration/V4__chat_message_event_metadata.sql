ALTER TABLE chat_messages
    ADD COLUMN event_type VARCHAR(100),
    ADD COLUMN target_user_id BIGINT REFERENCES users(id);
