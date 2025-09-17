-- BetterSaid Database Indexes
-- Performance optimization for common query patterns

-- Chats table indexes
CREATE INDEX IF NOT EXISTS idx_chats_public_code ON chats(public_code);
CREATE INDEX IF NOT EXISTS idx_chats_ttl ON chats(ttl_expires_at);
CREATE INDEX IF NOT EXISTS idx_chats_created_at ON chats(created_at);

-- Participants table indexes
CREATE INDEX IF NOT EXISTS idx_participants_chat_id ON participants(chat_id);
CREATE INDEX IF NOT EXISTS idx_participants_session_id ON participants(session_id);
CREATE INDEX IF NOT EXISTS idx_participants_joined_at ON participants(joined_at);

-- Messages table indexes
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_chat_time ON messages(chat_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_author_session ON messages(author_session);
CREATE INDEX IF NOT EXISTS idx_messages_role ON messages(role);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

-- Rewrites table indexes
CREATE INDEX IF NOT EXISTS idx_rewrites_message_id ON rewrites(message_id);
CREATE INDEX IF NOT EXISTS idx_rewrites_style ON rewrites(style);
CREATE INDEX IF NOT EXISTS idx_rewrites_created_at ON rewrites(created_at);

-- Rate limits table indexes
CREATE INDEX IF NOT EXISTS idx_rate_limits_public_code_ip ON rate_limits(public_code, ip_hash);
CREATE INDEX IF NOT EXISTS idx_rate_limits_endpoint ON rate_limits(endpoint);
CREATE INDEX IF NOT EXISTS idx_rate_limits_window_start ON rate_limits(window_start);
CREATE INDEX IF NOT EXISTS idx_rate_limits_created_at ON rate_limits(created_at);

-- Moderation logs table indexes
CREATE INDEX IF NOT EXISTS idx_moderation_logs_public_code ON moderation_logs(public_code);
CREATE INDEX IF NOT EXISTS idx_moderation_logs_endpoint ON moderation_logs(endpoint);
CREATE INDEX IF NOT EXISTS idx_moderation_logs_blocked ON moderation_logs(blocked);
CREATE INDEX IF NOT EXISTS idx_moderation_logs_created_at ON moderation_logs(created_at);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_chats_ttl_saved ON chats(ttl_expires_at, saved);
CREATE INDEX IF NOT EXISTS idx_messages_chat_role_time ON messages(chat_id, role, created_at);
CREATE INDEX IF NOT EXISTS idx_rate_limits_cleanup ON rate_limits(window_start, created_at);

-- Comments explaining index purposes
COMMENT ON INDEX idx_chats_public_code IS 'Fast lookup by room code for all API operations';
COMMENT ON INDEX idx_chats_ttl IS 'TTL cleanup queries - find expired rooms';
COMMENT ON INDEX idx_messages_chat_time IS 'Message polling - get messages since timestamp';
COMMENT ON INDEX idx_rate_limits_public_code_ip IS 'Rate limiting - check limits per room+IP';
COMMENT ON INDEX idx_moderation_logs_created_at IS 'Analytics and cleanup of moderation logs';
