-- Add image_url and suggested fields to get_menu_dishes function
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
    dietary_tags dietary_preference[],
    allergens TEXT[],
    token_cost INTEGER,
    protein_options TEXT[],
    is_featured BOOLEAN,
    can_order BOOLEAN,
    image_url TEXT,
    suggested_sides TEXT[],
    suggested_toppings TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id,
        d.name,
        d.description,
        d.preparation_instructions,
        d.prep_time_minutes,
        d.difficulty,
        d.serving_size,
        d.dietary_tags,
        d.allergens,
        d.token_cost,
        COALESCE(
            ARRAY(
                SELECT po.name 
                FROM public.dish_protein_options dpo
                JOIN public.protein_options po ON po.id = dpo.protein_option_id
                WHERE dpo.dish_id = d.id AND po.is_active = true
                ORDER BY po.display_order
            ),
            ARRAY[]::TEXT[]
        ) as protein_options,
        mi.is_featured,
        CASE 
            WHEN user_uuid IS NULL THEN true
            ELSE NOT EXISTS (
                SELECT 1 FROM public.user_allergens ua
                WHERE ua.user_id = user_uuid
                AND ua.allergen = ANY(d.allergens)
            )
        END as can_order,
        d.image_url,
        d.suggested_sides,
        d.suggested_toppings
    FROM public.dishes d
    INNER JOIN public.menu_items mi ON mi.dish_id = d.id
    WHERE mi.menu_month_id = menu_month_uuid
    AND d.is_active = true
    ORDER BY mi.display_order, d.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_menu_dishes(UUID, UUID) TO authenticated;
