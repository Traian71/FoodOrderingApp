-- Create function to get popular dishes
CREATE OR REPLACE FUNCTION get_popular_dishes()
RETURNS TABLE (
  name TEXT,
  description TEXT,
  token_cost INTEGER,
  total_orders BIGINT,
  total_quantity BIGINT
) 
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT 
    d.name,
    d.description,
    d.token_cost,
    COUNT(oi.id) as total_orders,
    SUM(oi.quantity) as total_quantity
  FROM dishes d
  INNER JOIN order_items oi ON d.id = oi.dish_id
  INNER JOIN orders o ON oi.order_id = o.id
  WHERE d.is_active = true
  GROUP BY d.id, d.name, d.description, d.token_cost
  ORDER BY COUNT(oi.id) DESC, SUM(oi.quantity) DESC
  LIMIT 5;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_popular_dishes() TO authenticated;
GRANT EXECUTE ON FUNCTION get_popular_dishes() TO anon;
