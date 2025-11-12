-- Fix remaining references to protein_option_id after protein options refactor
-- The dish_protein_options table now uses ingredient_id instead of protein_option_id
-- This migration updates get_dish_protein_options function to use the new schema
-- Created: 2024-11-12

-- Drop and recreate get_dish_protein_options function to use ingredients table
DROP FUNCTION IF EXISTS public.get_dish_protein_options(UUID) CASCADE;

CREATE OR REPLACE FUNCTION public.get_dish_protein_options(dish_uuid UUID)
RETURNS TABLE (
    id UUID,
    name TEXT,
    category TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id,
        i.name,
        i.category
    FROM public.ingredients i
    INNER JOIN public.dish_protein_options dpo ON dpo.ingredient_id = i.id
    WHERE dpo.dish_id = dish_uuid
    AND i.category = 'protein'
    ORDER BY i.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_dish_protein_options(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dish_protein_options(UUID) TO anon;

-- Add comment
COMMENT ON FUNCTION public.get_dish_protein_options IS 'Returns protein ingredient options for a dish from the ingredients table via dish_protein_options junction table';
