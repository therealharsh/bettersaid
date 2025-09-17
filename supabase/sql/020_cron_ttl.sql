-- BetterSaid TTL Cleanup
-- Automated cleanup of expired rooms and related data

-- Enable pg_cron extension (requires superuser, usually done by Supabase admin)
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- TTL cleanup function
CREATE OR REPLACE FUNCTION cleanup_expired_rooms()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count INTEGER := 0;
  expired_rooms UUID[];
BEGIN
  -- Find expired rooms
  SELECT ARRAY_AGG(id) INTO expired_rooms
  FROM chats 
  WHERE ttl_expires_at < NOW() AND saved = FALSE;
  
  -- If no expired rooms, return early
  IF expired_rooms IS NULL OR array_length(expired_rooms, 1) = 0 THEN
    RETURN 0;
  END IF;
  
  -- Log cleanup operation (without PII)
  INSERT INTO moderation_logs (
    public_code, 
    endpoint, 
    blocked, 
    categories,
    created_at
  )
  SELECT 
    public_code,
    'ttl_cleanup',
    FALSE,
    jsonb_build_object('expired', TRUE),
    NOW()
  FROM chats 
  WHERE id = ANY(expired_rooms);
  
  -- Delete expired chats (cascades to participants, messages, rewrites)
  DELETE FROM chats 
  WHERE id = ANY(expired_rooms);
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  -- Also cleanup old rate limits (older than 24 hours)
  DELETE FROM rate_limits 
  WHERE created_at < NOW() - INTERVAL '24 hours';
  
  -- Cleanup old moderation logs (older than 7 days)
  DELETE FROM moderation_logs 
  WHERE created_at < NOW() - INTERVAL '7 days';
  
  RETURN deleted_count;
END;
$$;

-- Function to cleanup rate limits for a specific window
CREATE OR REPLACE FUNCTION cleanup_rate_limits()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count INTEGER := 0;
BEGIN
  -- Remove rate limit entries older than 1 hour (sliding window)
  DELETE FROM rate_limits 
  WHERE window_start < NOW() - INTERVAL '1 hour';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RETURN deleted_count;
END;
$$;

-- Function to get cleanup statistics
CREATE OR REPLACE FUNCTION get_cleanup_stats()
RETURNS TABLE (
  total_rooms BIGINT,
  expired_rooms BIGINT,
  saved_rooms BIGINT,
  total_messages BIGINT,
  rate_limit_entries BIGINT,
  moderation_logs BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (SELECT COUNT(*) FROM chats) as total_rooms,
    (SELECT COUNT(*) FROM chats WHERE ttl_expires_at < NOW() AND saved = FALSE) as expired_rooms,
    (SELECT COUNT(*) FROM chats WHERE saved = TRUE) as saved_rooms,
    (SELECT COUNT(*) FROM messages) as total_messages,
    (SELECT COUNT(*) FROM rate_limits) as rate_limit_entries,
    (SELECT COUNT(*) FROM moderation_logs) as moderation_logs;
END;
$$;

-- Schedule TTL cleanup every 15 minutes
-- Note: This requires pg_cron extension and superuser privileges
-- In production, this would be set up by the Supabase admin or via their dashboard

-- SELECT cron.schedule(
--   'bettersaid-ttl-cleanup',
--   '*/15 * * * *', -- Every 15 minutes
--   'SELECT cleanup_expired_rooms();'
-- );

-- Schedule rate limit cleanup every hour
-- SELECT cron.schedule(
--   'bettersaid-rate-limit-cleanup', 
--   '0 * * * *', -- Every hour
--   'SELECT cleanup_rate_limits();'
-- );

-- Comments
COMMENT ON FUNCTION cleanup_expired_rooms() IS 'Removes expired rooms and cascades to all related data. Logs cleanup operations without PII.';
COMMENT ON FUNCTION cleanup_rate_limits() IS 'Removes old rate limit entries to prevent table bloat.';
COMMENT ON FUNCTION get_cleanup_stats() IS 'Returns statistics about data retention and cleanup effectiveness.';

-- Example usage:
-- SELECT cleanup_expired_rooms(); -- Manual cleanup
-- SELECT * FROM get_cleanup_stats(); -- View statistics
