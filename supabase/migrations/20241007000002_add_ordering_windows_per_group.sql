-- Migration: Add ordering windows per delivery group
-- This migration implements group-specific ordering windows for menu months
-- Note: delivery_group and group_assigned already exist in users table

-- Step 1: Create index for group_assigned (field already exists)
CREATE INDEX IF NOT EXISTS idx_users_group_assigned ON public.users(group_assigned);

-- Step 2: Modify menu_months table to add ordering windows for each group
ALTER TABLE public.menu_months
ADD COLUMN order_window_group1_start TIMESTAMP WITH TIME ZONE,
ADD COLUMN order_window_group1_end TIMESTAMP WITH TIME ZONE,
ADD COLUMN order_window_group2_start TIMESTAMP WITH TIME ZONE,
ADD COLUMN order_window_group2_end TIMESTAMP WITH TIME ZONE,
ADD COLUMN order_window_group3_start TIMESTAMP WITH TIME ZONE,
ADD COLUMN order_window_group3_end TIMESTAMP WITH TIME ZONE,
ADD COLUMN order_window_group4_start TIMESTAMP WITH TIME ZONE,
ADD COLUMN order_window_group4_end TIMESTAMP WITH TIME ZONE;

-- Add constraints to ensure ordering windows are valid
ALTER TABLE public.menu_months
ADD CONSTRAINT menu_months_group1_window_check 
  CHECK (order_window_group1_start IS NULL OR order_window_group1_end IS NULL OR order_window_group1_start < order_window_group1_end),
ADD CONSTRAINT menu_months_group2_window_check 
  CHECK (order_window_group2_start IS NULL OR order_window_group2_end IS NULL OR order_window_group2_start < order_window_group2_end),
ADD CONSTRAINT menu_months_group3_window_check 
  CHECK (order_window_group3_start IS NULL OR order_window_group3_end IS NULL OR order_window_group3_start < order_window_group3_end),
ADD CONSTRAINT menu_months_group4_window_check 
  CHECK (order_window_group4_start IS NULL OR order_window_group4_end IS NULL OR order_window_group4_start < order_window_group4_end);

-- Step 3: Create function to check if user can order from a menu
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
    -- Get current timestamp
    v_now := NOW();
    
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

-- Step 4: Create function to get user's ordering window for a menu
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
BEGIN
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
                v_group_assigned AND NOW() >= v_menu_month.order_window_group1_start AND NOW() <= v_menu_month.order_window_group1_end,
                v_menu_month.order_window_group1_start,
                v_menu_month.order_window_group1_end,
                v_user_group,
                v_group_assigned;
        WHEN '2' THEN
            RETURN QUERY SELECT 
                v_group_assigned AND NOW() >= v_menu_month.order_window_group2_start AND NOW() <= v_menu_month.order_window_group2_end,
                v_menu_month.order_window_group2_start,
                v_menu_month.order_window_group2_end,
                v_user_group,
                v_group_assigned;
        WHEN '3' THEN
            RETURN QUERY SELECT 
                v_group_assigned AND NOW() >= v_menu_month.order_window_group3_start AND NOW() <= v_menu_month.order_window_group3_end,
                v_menu_month.order_window_group3_start,
                v_menu_month.order_window_group3_end,
                v_user_group,
                v_group_assigned;
        WHEN '4' THEN
            RETURN QUERY SELECT 
                v_group_assigned AND NOW() >= v_menu_month.order_window_group4_start AND NOW() <= v_menu_month.order_window_group4_end,
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

-- Step 5: Add comment explaining the new structure
COMMENT ON COLUMN public.users.delivery_group IS 'Delivery group (1-4) assigned by admin. Determines which ordering window the user can use.';
COMMENT ON COLUMN public.users.group_assigned IS 'Whether admin has assigned this user to a delivery group. Users cannot order until assigned.';
COMMENT ON COLUMN public.menu_months.order_window_group1_start IS 'Start of ordering window for delivery group 1';
COMMENT ON COLUMN public.menu_months.order_window_group1_end IS 'End of ordering window for delivery group 1';
COMMENT ON COLUMN public.menu_months.order_window_group2_start IS 'Start of ordering window for delivery group 2';
COMMENT ON COLUMN public.menu_months.order_window_group2_end IS 'End of ordering window for delivery group 2';
COMMENT ON COLUMN public.menu_months.order_window_group3_start IS 'Start of ordering window for delivery group 3';
COMMENT ON COLUMN public.menu_months.order_window_group3_end IS 'End of ordering window for delivery group 3';
COMMENT ON COLUMN public.menu_months.order_window_group4_start IS 'Start of ordering window for delivery group 4';
COMMENT ON COLUMN public.menu_months.order_window_group4_end IS 'End of ordering window for delivery group 4';
