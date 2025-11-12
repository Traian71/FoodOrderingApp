-- Admin dashboard functions with SECURITY DEFINER to bypass RLS
-- These functions are specifically for admin dashboard operations

-- Function to get recent orders with user details
CREATE OR REPLACE FUNCTION get_recent_orders(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  status TEXT,
  total_meals INTEGER,
  delivery_group TEXT,
  created_at TIMESTAMPTZ,
  first_name TEXT,
  last_name TEXT,
  email TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    o.id,
    o.user_id,
    o.status::TEXT,
    o.total_meals,
    o.delivery_group::TEXT,
    o.created_at,
    u.first_name,
    u.last_name,
    u.email
  FROM orders o
  INNER JOIN users u ON o.user_id = u.id
  ORDER BY o.created_at DESC
  LIMIT limit_count;
END;
$$;

-- Function to get monthly revenue
CREATE OR REPLACE FUNCTION get_monthly_revenue(target_year INTEGER DEFAULT NULL, target_month INTEGER DEFAULT NULL)
RETURNS DECIMAL(10,2)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  revenue_total DECIMAL(10,2);
  year_param INTEGER;
  month_param INTEGER;
BEGIN
  -- Use current year/month if not provided
  year_param := COALESCE(target_year, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
  month_param := COALESCE(target_month, EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER);
  
  SELECT COALESCE(SUM(amount_eur::DECIMAL / 100), 0) INTO revenue_total
  FROM billing_history
  WHERE payment_status = 'paid'
    AND EXTRACT(YEAR FROM billing_period_start) = year_param
    AND EXTRACT(MONTH FROM billing_period_start) = month_param;
    
  RETURN revenue_total;
END;
$$;

-- Function to get revenue trend (last 6 months)
CREATE OR REPLACE FUNCTION get_revenue_trend()
RETURNS TABLE (
  month TEXT,
  revenue DECIMAL(10,2)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    TO_CHAR(billing_period_start, 'Mon') as month,
    SUM(amount_eur::DECIMAL / 100) as revenue
  FROM billing_history
  WHERE payment_status = 'paid'
    AND billing_period_start >= CURRENT_DATE - INTERVAL '6 months'
  GROUP BY TO_CHAR(billing_period_start, 'Mon'), EXTRACT(MONTH FROM billing_period_start)
  ORDER BY EXTRACT(MONTH FROM billing_period_start);
END;
$$;

-- Function to get orders by status for charts
CREATE OR REPLACE FUNCTION get_orders_by_status()
RETURNS TABLE (
  status TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    o.status::TEXT,
    o.created_at
  FROM orders o
  ORDER BY o.created_at DESC
  LIMIT 100;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_recent_orders(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_monthly_revenue(INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_revenue_trend() TO authenticated;
GRANT EXECUTE ON FUNCTION get_orders_by_status() TO authenticated;
