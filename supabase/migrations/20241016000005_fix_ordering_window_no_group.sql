-- Fix get_user_ordering_window to handle users without assigned delivery groups
-- This allows the frontend to properly detect and display messages for unassigned users

CREATE OR REPLACE FUNCTION public.get_user_ordering_window(
    p_user_id UUID,
    p_menu_month_id UUID
)
RETURNS TABLE (
    can_order BOOLEAN,
    window_start TIMESTAMP WITH TIME ZONE,
    window_end TIMESTAMP WITH TIME ZONE,
    delivery_group delivery_group,
    group_assigned BOOLEAN
) AS $$
DECLARE
    v_user_group delivery_group;
    v_group_assigned BOOLEAN;
    v_menu_month RECORD;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Get current timestamp in Copenhagen timezone
    v_now := NOW() AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Copenhagen';
    
    -- Get user's delivery group and assignment status
    SELECT u.delivery_group, u.group_assigned
    INTO v_user_group, v_group_assigned
    FROM public.users u
    WHERE u.id = p_user_id;
    
    -- If user not found, return empty result
    IF NOT FOUND THEN
        RETURN;
    END IF;
    
    -- If user has no delivery group assigned, return with group_assigned=false
    IF v_user_group IS NULL OR v_group_assigned = false THEN
        RETURN QUERY SELECT 
            false,
            NULL::TIMESTAMP WITH TIME ZONE,
            NULL::TIMESTAMP WITH TIME ZONE,
            v_user_group,
            COALESCE(v_group_assigned, false);
        RETURN;
    END IF;
    
    -- Get menu month details
    SELECT *
    INTO v_menu_month
    FROM public.menu_months
    WHERE id = p_menu_month_id AND is_active = true;
    
    -- If menu not found, return user info with nulls
    IF v_menu_month IS NULL THEN
        RETURN QUERY SELECT 
            false,
            NULL::TIMESTAMP WITH TIME ZONE,
            NULL::TIMESTAMP WITH TIME ZONE,
            v_user_group,
            v_group_assigned;
        RETURN;
    END IF;
    
    -- Return ordering window based on user's delivery group
    CASE v_user_group
        WHEN '1' THEN
            RETURN QUERY SELECT 
                v_group_assigned AND v_now >= v_menu_month.order_window_group1_start AND v_now <= v_menu_month.order_window_group1_end,
                v_menu_month.order_window_group1_start,
                v_menu_month.order_window_group1_end,
                v_user_group,
                v_group_assigned;
        WHEN '2' THEN
            RETURN QUERY SELECT 
                v_group_assigned AND v_now >= v_menu_month.order_window_group2_start AND v_now <= v_menu_month.order_window_group2_end,
                v_menu_month.order_window_group2_start,
                v_menu_month.order_window_group2_end,
                v_user_group,
                v_group_assigned;
        WHEN '3' THEN
            RETURN QUERY SELECT 
                v_group_assigned AND v_now >= v_menu_month.order_window_group3_start AND v_now <= v_menu_month.order_window_group3_end,
                v_menu_month.order_window_group3_start,
                v_menu_month.order_window_group3_end,
                v_user_group,
                v_group_assigned;
        WHEN '4' THEN
            RETURN QUERY SELECT 
                v_group_assigned AND v_now >= v_menu_month.order_window_group4_start AND v_now <= v_menu_month.order_window_group4_end,
                v_menu_month.order_window_group4_start,
                v_menu_month.order_window_group4_end,
                v_user_group,
                v_group_assigned;
    END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add helpful comment
COMMENT ON FUNCTION public.get_user_ordering_window IS 'Returns user ordering window details for a menu month. Returns data with group_assigned=false for users without assigned delivery groups. Uses Europe/Copenhagen timezone.';
