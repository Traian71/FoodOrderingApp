-- Add simple health check function for connection testing
-- This is a lightweight function that just returns the current timestamp
-- Used by the frontend to test database connectivity

CREATE OR REPLACE FUNCTION get_current_timestamp()
RETURNS TIMESTAMP WITH TIME ZONE
LANGUAGE sql
STABLE
AS $$
  SELECT NOW();
$$;

-- Grant execute permission to authenticated and anon users
GRANT EXECUTE ON FUNCTION get_current_timestamp() TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_timestamp() TO anon;

-- Add comment
COMMENT ON FUNCTION get_current_timestamp() IS 'Lightweight function for connection health checks';
