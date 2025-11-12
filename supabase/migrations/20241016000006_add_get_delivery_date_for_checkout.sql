-- Add get_delivery_date_for_checkout function
-- This function returns the delivery date for a user's delivery group from the delivery_schedules table

-- Drop existing function with any signature
DROP FUNCTION IF EXISTS public.get_delivery_date_for_checkout(UUID, TEXT);
DROP FUNCTION IF EXISTS public.get_delivery_date_for_checkout(UUID, delivery_group);

CREATE OR REPLACE FUNCTION public.get_delivery_date_for_checkout(
    p_menu_month_id UUID,
    p_delivery_group delivery_group
)
RETURNS TABLE (
    delivery_date DATE,
    time_window_start TIME,
    time_window_end TIME,
    driver_notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ds.scheduled_date as delivery_date,
        ds.time_window_start,
        ds.time_window_end,
        ds.driver_notes
    FROM public.delivery_schedules ds
    WHERE ds.menu_month_id = p_menu_month_id
      AND ds.delivery_group = p_delivery_group
      AND ds.is_completed = false
    ORDER BY ds.scheduled_date ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.get_delivery_date_for_checkout(UUID, delivery_group) TO authenticated;

-- Add helpful comment
COMMENT ON FUNCTION public.get_delivery_date_for_checkout IS 'Returns the next delivery date and time window for a specific delivery group and menu month';
