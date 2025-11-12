-- Migration: Fix ordering window functions to use Copenhagen timezone
-- This ensures all ordering window checks use Europe/Copenhagen timezone consistently
-- Created: 2024-10-15

-- Update can_user_order_from_menu function to use Copenhagen timezone
CREATE OR REPLACE FUNCTION public.can_user_order_from_menu(
    p_user_id UUID,
    p_menu_month_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_group delivery_group;
    v_group_assigned BOOLEAN;
    v_menu_month RECORD;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Get current timestamp in Copenhagen timezone
    v_now := NOW() AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Copenhagen';
    
    -- Get user's delivery group and assignment status
    SELECT delivery_group, group_assigned
    INTO v_user_group, v_group_assigned
    FROM public.users
    WHERE id = p_user_id;
    
    -- If user not found or not assigned to a group, return false
    IF v_user_group IS NULL OR v_group_assigned = false THEN
        RETURN false;
    END IF;
    
    -- Get menu month details
    SELECT *
    INTO v_menu_month
    FROM public.menu_months
    WHERE id = p_menu_month_id AND is_active = true;
    
    -- If menu not found or not active, return false
    IF v_menu_month IS NULL THEN
        RETURN false;
    END IF;
    
    -- Check ordering window based on user's delivery group
    CASE v_user_group
        WHEN '1' THEN
            RETURN v_now >= v_menu_month.order_window_group1_start 
               AND v_now <= v_menu_month.order_window_group1_end;
        WHEN '2' THEN
            RETURN v_now >= v_menu_month.order_window_group2_start 
               AND v_now <= v_menu_month.order_window_group2_end;
        WHEN '3' THEN
            RETURN v_now >= v_menu_month.order_window_group3_start 
               AND v_now <= v_menu_month.order_window_group3_end;
        WHEN '4' THEN
            RETURN v_now >= v_menu_month.order_window_group4_start 
               AND v_now <= v_menu_month.order_window_group4_end;
        ELSE
            RETURN false;
    END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update get_user_ordering_window function to use Copenhagen timezone
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
    IF v_user_group IS NULL THEN
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.can_user_order_from_menu(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_ordering_window(UUID, UUID) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION public.can_user_order_from_menu IS 'Checks if user can order from menu based on their delivery group ordering window. Uses Europe/Copenhagen timezone.';
COMMENT ON FUNCTION public.get_user_ordering_window IS 'Returns user ordering window details for a menu month. Uses Europe/Copenhagen timezone.';
