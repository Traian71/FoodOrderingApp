-- Migration: Fix get_menu_dishes function to remove dietary_tags and allergens columns
-- These columns were removed from dishes table in 20241021000002
-- The function needs to be updated to not reference them
-- Created: 2024-11-04

DROP FUNCTION IF EXISTS public.get_menu_dishes(UUID, UUID) CASCADE;

CREATE OR REPLACE FUNCTION public.get_menu_dishes(
    menu_month_uuid UUID,
    user_uuid UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    preparation_instructions TEXT,
    prep_time_minutes INTEGER,
    difficulty difficulty_level,
    serving_size INTEGER,
    token_cost INTEGER,
    protein_options TEXT[],
    is_featured BOOLEAN,
    can_order BOOLEAN,
    image_url TEXT,
    suggested_sides TEXT[],
    suggested_toppings TEXT[],
    hide_nutrition_info BOOLEAN
) AS $$
DECLARE
    v_user_group delivery_group;
    v_group_assigned BOOLEAN;
    v_menu_month RECORD;
    v_now TIMESTAMP WITH TIME ZONE;
    v_window_start TIMESTAMP WITH TIME ZONE;
    v_window_end TIMESTAMP WITH TIME ZONE;
    v_in_ordering_window BOOLEAN;
BEGIN
    -- Get current time in Copenhagen timezone
    v_now := NOW() AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Copenhagen';
    v_in_ordering_window := false;
    
    -- If user_uuid is provided, check their ordering window
    IF user_uuid IS NOT NULL THEN
        -- Get user's delivery group and assignment status
        SELECT u.delivery_group, u.group_assigned
        INTO v_user_group, v_group_assigned
        FROM public.users u
        WHERE u.id = user_uuid;
        
        -- Get menu month details
        SELECT *
        INTO v_menu_month
        FROM public.menu_months mm
        WHERE mm.id = menu_month_uuid AND mm.is_active = true;
        
        -- Check if user is in their ordering window
        IF v_user_group IS NOT NULL AND v_group_assigned = true AND v_menu_month IS NOT NULL THEN
            CASE v_user_group
                WHEN '1' THEN
                    v_window_start := v_menu_month.order_window_group1_start;
                    v_window_end := v_menu_month.order_window_group1_end;
                WHEN '2' THEN
                    v_window_start := v_menu_month.order_window_group2_start;
                    v_window_end := v_menu_month.order_window_group2_end;
                WHEN '3' THEN
                    v_window_start := v_menu_month.order_window_group3_start;
                    v_window_end := v_menu_month.order_window_group3_end;
                WHEN '4' THEN
                    v_window_start := v_menu_month.order_window_group4_start;
                    v_window_end := v_menu_month.order_window_group4_end;
            END CASE;
            
            -- Check if current time is within the window
            IF v_window_start IS NOT NULL AND v_window_end IS NOT NULL THEN
                v_in_ordering_window := v_now >= v_window_start AND v_now <= v_window_end;
            END IF;
        END IF;
    END IF;
    
    RETURN QUERY
    SELECT 
        d.id AS id,
        d.name AS name,
        d.description AS description,
        d.preparation_instructions AS preparation_instructions,
        d.prep_time_minutes AS prep_time_minutes,
        d.difficulty AS difficulty,
        d.serving_size AS serving_size,
        d.token_cost AS token_cost,
        -- Get protein options from ingredients table
        COALESCE(
            ARRAY(
                SELECT i.name 
                FROM public.dish_protein_options dpo
                JOIN public.ingredients i ON i.id = dpo.ingredient_id
                WHERE dpo.dish_id = d.id AND i.category = 'protein'
                ORDER BY i.name
            ),
            ARRAY[]::TEXT[]
        ) AS protein_options,
        mi.is_featured AS is_featured,
        -- Simplified can_order logic - only check ordering window
        -- Allergen checking is now done on client side since allergens are computed from ingredients
        CASE 
            WHEN user_uuid IS NULL THEN true
            WHEN NOT v_in_ordering_window THEN false
            ELSE true
        END AS can_order,
        d.image_url AS image_url,
        d.suggested_sides AS suggested_sides,
        d.suggested_toppings AS suggested_toppings,
        mi.hide_nutrition_info AS hide_nutrition_info
    FROM public.dishes d
    INNER JOIN public.menu_items mi ON mi.dish_id = d.id
    WHERE mi.menu_month_id = menu_month_uuid
    AND d.is_active = true
    ORDER BY mi.display_order, d.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_menu_dishes IS 'Returns menu dishes with protein options from ingredients table and ordering window validation. Note: dietary_tags and allergens are computed from ingredients on the client side.';

GRANT EXECUTE ON FUNCTION public.get_menu_dishes(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_menu_dishes(UUID, UUID) TO anon;
