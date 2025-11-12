-- Migration: Remove dietary_tags and allergens columns from dishes table
-- These values are now computed from ingredients on the client side

-- First, drop the menu_view that depends on these columns
DROP VIEW IF EXISTS public.menu_view CASCADE;

-- Drop the dietary_tags column
ALTER TABLE dishes DROP COLUMN IF EXISTS dietary_tags;

-- Drop the allergens column
ALTER TABLE dishes DROP COLUMN IF EXISTS allergens;

-- Recreate menu_view without dietary_tags and allergens
CREATE OR REPLACE VIEW public.menu_view AS
SELECT 
    mm.id as menu_month_id,
    mm.month_number,
    mm.year,
    mm.start_date,
    mm.end_date,
    mm.delivery_start_date,
    mm.delivery_end_date,
    mm.order_cutoff_date,
    mm.is_active as menu_is_active,
    d.id as dish_id,
    d.name as dish_name,
    d.description,
    d.preparation_instructions,
    d.prep_time_minutes,
    d.difficulty,
    d.serving_size,
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
    mi.display_order
FROM public.menu_months mm
INNER JOIN public.menu_items mi ON mi.menu_month_id = mm.id
INNER JOIN public.dishes d ON d.id = mi.dish_id
WHERE d.is_active = true;

-- Grant access to the view
GRANT SELECT ON public.menu_view TO authenticated;
GRANT SELECT ON public.menu_view TO anon;

-- Add comment explaining the change
COMMENT ON TABLE dishes IS 'Dishes table. Note: dietary_tags and allergens are computed from dish_ingredients on the client side, not stored in the database.';
