-- Migration: Add function to get user's delivery schedule
-- This migration creates a function to fetch delivery schedule based on user's delivery group
-- Created: 2024-10-14

-- Create function to get user's delivery schedule for a specific menu month
CREATE OR REPLACE FUNCTION public.get_user_delivery_schedule(
    p_user_id UUID,
    p_menu_month_id UUID
)
RETURNS TABLE (
    id UUID,
    delivery_group delivery_group,
    menu_month_id UUID,
    scheduled_date DATE,
    time_window_start TIME,
    time_window_end TIME,
    driver_notes TEXT,
    is_completed BOOLEAN
) AS $$
DECLARE
    v_user_group delivery_group;
BEGIN
    -- Get user's delivery group
    SELECT u.delivery_group
    INTO v_user_group
    FROM public.users u
    WHERE u.id = p_user_id;
    
    -- If user not found or no delivery group assigned, return empty result
    IF v_user_group IS NULL THEN
        RETURN;
    END IF;
    
    -- Return delivery schedule for user's group and menu month
    RETURN QUERY
    SELECT 
        ds.id,
        ds.delivery_group,
        ds.menu_month_id,
        ds.scheduled_date,
        ds.time_window_start,
        ds.time_window_end,
        ds.driver_notes,
        ds.is_completed
    FROM public.delivery_schedules ds
    WHERE ds.delivery_group = v_user_group
      AND ds.menu_month_id = p_menu_month_id
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.get_user_delivery_schedule(UUID, UUID) TO authenticated;

-- Add helpful comment
COMMENT ON FUNCTION public.get_user_delivery_schedule IS 'Returns the delivery schedule for a user based on their delivery group and menu month';
