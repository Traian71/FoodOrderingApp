-- Update admin dashboard functions to use monthly menus instead of weekly menus

-- Drop the old weekly menus count function
DROP FUNCTION IF EXISTS get_weekly_menus_count();

-- Create new monthly menus count function
CREATE OR REPLACE FUNCTION get_monthly_menus_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM public.menu_months WHERE is_active = true);
END;
$$;

-- Create function to get total token balance across all users
CREATE OR REPLACE FUNCTION get_total_token_balance()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (SELECT COALESCE(SUM(current_balance), 0) FROM public.token_wallets);
END;
$$;
