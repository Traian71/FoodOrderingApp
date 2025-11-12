-- Update RLS policies and views that referenced available_protein_options
-- This migration updates the menu_view to use the new protein_options tables

-- Drop the old menu_view if it exists
DROP VIEW IF EXISTS public.menu_view CASCADE;

-- Recreate menu_view with protein options from new tables
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
    mi.display_order
FROM public.menu_months mm
INNER JOIN public.menu_items mi ON mi.menu_month_id = mm.id
INNER JOIN public.dishes d ON d.id = mi.dish_id
WHERE d.is_active = true;

-- Grant access to the view
GRANT SELECT ON public.menu_view TO authenticated;
GRANT SELECT ON public.menu_view TO anon;
