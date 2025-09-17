-- BetterSaid Database Schema
-- Initial tables for anonymous conflict mediation platform

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Chats table - stores room information
CREATE TABLE IF NOT EXISTS chats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  public_code TEXT UNIQUE NOT NULL,
  secret_hash TEXT NOT NULL,
  view_secret_hash TEXT NULL,
  goal TEXT NOT NULL,
  ttl_expires_at TIMESTAMPTZ NOT NULL,
  saved BOOLEAN NOT NULL DEFAULT FALSE,
  settings JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Participants table - tracks who's in each room
CREATE TABLE IF NOT EXISTS participants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  session_id UUID NOT NULL,
  display_name TEXT NOT NULL,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Messages table - stores all messages in rooms
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  author_session UUID NULL,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Rewrites table - stores AI-generated message alternatives
CREATE TABLE IF NOT EXISTS rewrites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  style TEXT NOT NULL CHECK (style IN ('calm', 'direct', 'brief')),
  content TEXT NOT NULL,
  safety_tags JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Rate limiting table - tracks API usage by public_code + IP hash
CREATE TABLE IF NOT EXISTS rate_limits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  public_code TEXT NOT NULL,
  ip_hash TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 1,
  window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Moderation logs table - tracks content safety decisions (no PII)
CREATE TABLE IF NOT EXISTS moderation_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  public_code TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  blocked BOOLEAN NOT NULL DEFAULT FALSE,
  categories JSONB, -- e.g., {"violence": false, "hate": true, "self_harm": false}
  severity TEXT, -- 'low', 'medium', 'high'
  token_count INTEGER,
  latency_ms INTEGER,
  model_used TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Comments explaining the privacy-first design
COMMENT ON TABLE chats IS 'Room metadata. Secrets are hashed, never stored in plain text.';
COMMENT ON TABLE participants IS 'Session tracking. Display names are ephemeral, not linked to real identity.';
COMMENT ON TABLE messages IS 'Message content. Auto-deleted via TTL. No PII stored.';
COMMENT ON TABLE rewrites IS 'AI-generated alternatives. Linked to messages for context.';
COMMENT ON TABLE rate_limits IS 'API rate limiting. IP addresses are hashed for privacy.';
COMMENT ON TABLE moderation_logs IS 'Safety system logs. No message content or PII stored.';

COMMENT ON COLUMN chats.secret_hash IS 'Hashed secret for room access. Never log the plain secret.';
COMMENT ON COLUMN chats.view_secret_hash IS 'Optional view-only access hash.';
COMMENT ON COLUMN participants.session_id IS 'Temporary session identifier, not linked to user identity.';
COMMENT ON COLUMN messages.author_session IS 'Links to participant session_id for message attribution.';
COMMENT ON COLUMN moderation_logs.categories IS 'Boolean flags for content categories, no actual content.';
