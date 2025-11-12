-- Refactor protein options to use ingredients table instead of separate protein_options table
-- This migration connects dishes to protein ingredients via dish_protein_options

-- Step 1: Rename dish_protein_options to dish_protein_options_old for backup
ALTER TABLE IF EXISTS public.dish_protein_options RENAME TO dish_protein_options_old;

-- Step 2: Create new dish_protein_options table that references ingredients
CREATE TABLE public.dish_protein_options (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    dish_id UUID REFERENCES public.dishes(id) ON DELETE CASCADE NOT NULL,
    ingredient_id UUID REFERENCES public.ingredients(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(dish_id, ingredient_id)
);

-- Step 3: Create indexes for performance
CREATE INDEX idx_dish_protein_options_dish_id ON public.dish_protein_options(dish_id);
CREATE INDEX idx_dish_protein_options_ingredient_id ON public.dish_protein_options(ingredient_id);

-- Step 4: Migrate data from old table to new table
-- Match protein_options.name to ingredients.name where category='protein'
INSERT INTO public.dish_protein_options (dish_id, ingredient_id)
SELECT DISTINCT 
    dpo_old.dish_id,
    i.id as ingredient_id
FROM public.dish_protein_options_old dpo_old
JOIN public.protein_options po ON po.id = dpo_old.protein_option_id
JOIN public.ingredients i ON LOWER(i.name) = LOWER(po.name) AND i.category = 'protein'
ON CONFLICT (dish_id, ingredient_id) DO NOTHING;

-- Step 5: Update RLS policies
ALTER TABLE public.dish_protein_options ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read dish protein options
CREATE POLICY "Allow read access to dish protein options"
    ON public.dish_protein_options FOR SELECT
    TO authenticated
    USING (true);

-- Allow admin users to manage dish protein options
CREATE POLICY "Allow admin users to manage dish protein options"
    ON public.dish_protein_options FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE id = auth.uid()
            AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE id = auth.uid()
            AND is_active = true
        )
    );

-- Step 6: Update get_dish_protein_options function to use ingredients
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

-- Step 7: Update get_menu_dishes function to use ingredients for protein options
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
    image_url TEXT
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
                SELECT i.name 
                FROM public.dish_protein_options dpo
                JOIN public.ingredients i ON i.id = dpo.ingredient_id
                WHERE dpo.dish_id = d.id AND i.category = 'protein'
                ORDER BY i.name
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
        d.image_url
    FROM public.dishes d
    INNER JOIN public.menu_items mi ON mi.dish_id = d.id
    WHERE mi.menu_month_id = menu_month_uuid
    AND d.is_active = true
    ORDER BY mi.display_order, d.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Update validate_cart_item_protein function to use ingredients
DROP FUNCTION IF EXISTS public.validate_cart_item_protein() CASCADE;

CREATE OR REPLACE FUNCTION public.validate_cart_item_protein()
RETURNS TRIGGER AS $$
BEGIN
    -- If protein option is specified, validate it exists for this dish
    IF NEW.protein_option IS NOT NULL AND NEW.protein_option != '' THEN
        IF NOT EXISTS (
            SELECT 1 
            FROM public.dish_protein_options dpo
            JOIN public.ingredients i ON i.id = dpo.ingredient_id
            WHERE dpo.dish_id = NEW.dish_id
            AND i.name = NEW.protein_option
            AND i.category = 'protein'
        ) THEN
            RAISE EXCEPTION 'Invalid protein option "%" for dish id %', NEW.protein_option, NEW.dish_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers for cart items validation
DROP TRIGGER IF EXISTS validate_cart_item_protein_trigger ON public.cart_items;
CREATE TRIGGER validate_cart_item_protein_trigger
    BEFORE INSERT OR UPDATE ON public.cart_items
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_cart_item_protein();

DROP TRIGGER IF EXISTS validate_guest_cart_item_protein_trigger ON public.guest_cart_items;
CREATE TRIGGER validate_guest_cart_item_protein_trigger
    BEFORE INSERT OR UPDATE ON public.guest_cart_items
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_cart_item_protein();

-- Step 9: Grant permissions
GRANT EXECUTE ON FUNCTION public.get_dish_protein_options(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_menu_dishes(UUID, UUID) TO authenticated;

-- Step 10: Drop old backup table after successful migration
-- Uncomment this line after verifying the migration worked correctly
-- DROP TABLE IF EXISTS public.dish_protein_options_old CASCADE;

-- Note: The protein_options table is kept for now in case it's referenced elsewhere
-- You can drop it manually after verifying everything works:
-- DROP TABLE IF EXISTS public.protein_options CASCADE;

COMMENT ON TABLE public.dish_protein_options IS 'Junction table connecting dishes to protein ingredient options from the ingredients table';
COMMENT ON COLUMN public.dish_protein_options.ingredient_id IS 'References ingredients table where category=protein';
