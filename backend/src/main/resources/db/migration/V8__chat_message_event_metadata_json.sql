ALTER TABLE chat_messages
    ADD COLUMN event_metadata_json TEXT NOT NULL DEFAULT '{}';
