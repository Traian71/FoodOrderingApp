-- ============================================================================
-- COMPLETE INGREDIENT ENHANCEMENTS AND PROTEIN OPTIONS REFACTOR
-- ============================================================================
-- This migration does the following:
-- 1. Adds storage_type and nutrition_data_complete to ingredients (admin only)
-- 2. Adds hide_nutrition_info to menu_items (toggles nutrition tab visibility)
-- 3. Refactors dish_protein_options to use ingredients table instead of protein_options
-- 4. Updates ALL functions, triggers, and references to use new protein mechanism
-- ============================================================================

-- ============================================================================
-- PART 1: ADD NEW COLUMNS TO INGREDIENTS AND MENU_ITEMS
-- ============================================================================

-- Add admin-only columns to ingredients table
ALTER TABLE public.ingredients
ADD COLUMN IF NOT EXISTS storage_type TEXT CHECK (storage_type IN ('raw', 'dried', 'frozen')) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS nutrition_data_complete BOOLEAN DEFAULT false;

-- Add nutrition visibility toggle to menu_items
ALTER TABLE public.menu_items
ADD COLUMN IF NOT EXISTS hide_nutrition_info BOOLEAN DEFAULT false;

-- Add helpful comments
COMMENT ON COLUMN public.ingredients.storage_type IS 'Storage type for admin reference only (raw/dried/frozen) - no impact on platform functionality';
COMMENT ON COLUMN public.ingredients.nutrition_data_complete IS 'Admin tag to track completion of nutrition data entry - no impact on calculations or platform functionality';
COMMENT ON COLUMN public.menu_items.hide_nutrition_info IS 'When true, hides the nutrition information tab on the dish page (user will only see ingredients, instructions, etc.)';

-- ============================================================================
-- PART 2: REFACTOR DISH_PROTEIN_OPTIONS TO USE INGREDIENTS
-- ============================================================================

-- Backup existing dish_protein_options table
ALTER TABLE IF EXISTS public.dish_protein_options RENAME TO dish_protein_options_backup;

-- Create new dish_protein_options table that references ingredients
CREATE TABLE public.dish_protein_options (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    dish_id UUID REFERENCES public.dishes(id) ON DELETE CASCADE NOT NULL,
    ingredient_id UUID REFERENCES public.ingredients(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(dish_id, ingredient_id)
);

-- Create indexes for performance (only if they don't exist)
CREATE INDEX IF NOT EXISTS idx_dish_protein_options_dish_id ON public.dish_protein_options(dish_id);
CREATE INDEX IF NOT EXISTS idx_dish_protein_options_ingredient_id ON public.dish_protein_options(ingredient_id);

-- Migrate data from old table to new table
-- Match protein_options.name to ingredients.name where category='protein'
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'dish_protein_options_backup') THEN
        INSERT INTO public.dish_protein_options (dish_id, ingredient_id)
        SELECT DISTINCT 
            dpo_old.dish_id,
            i.id as ingredient_id
        FROM public.dish_protein_options_backup dpo_old
        JOIN public.protein_options po ON po.id = dpo_old.protein_option_id
        JOIN public.ingredients i ON LOWER(i.name) = LOWER(po.name) AND i.category = 'protein'
        ON CONFLICT (dish_id, ingredient_id) DO NOTHING;
    END IF;
END $$;

-- ============================================================================
-- PART 3: UPDATE RLS POLICIES FOR DISH_PROTEIN_OPTIONS
-- ============================================================================

ALTER TABLE public.dish_protein_options ENABLE ROW LEVEL SECURITY;

-- Drop old policies if they exist
DROP POLICY IF EXISTS "Allow read access to dish protein options" ON public.dish_protein_options;
DROP POLICY IF EXISTS "Allow admin users to manage dish protein options" ON public.dish_protein_options;

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

-- ============================================================================
-- PART 4: UPDATE ALL FUNCTIONS TO USE INGREDIENTS FOR PROTEIN OPTIONS
-- ============================================================================

-- Drop all functions that reference protein_options
DROP FUNCTION IF EXISTS public.get_dish_protein_options(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.get_menu_dishes(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.validate_cart_item_protein() CASCADE;

-- ============================================================================
-- Function: get_dish_protein_options
-- Returns protein ingredients available for a specific dish
-- ============================================================================
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

COMMENT ON FUNCTION public.get_dish_protein_options IS 'Returns protein ingredients available for a specific dish from the ingredients table';

-- ============================================================================
-- Function: get_menu_dishes
-- Returns all dishes for a menu month with protein options from ingredients
-- Includes ordering window validation and allergen checks
-- ============================================================================
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
        d.dietary_tags AS dietary_tags,
        d.allergens AS allergens,
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
        CASE 
            WHEN user_uuid IS NULL THEN true
            -- Check ordering window first
            WHEN NOT v_in_ordering_window THEN false
            -- Then check allergens
            ELSE NOT EXISTS (
                SELECT 1 FROM public.user_allergens ua
                WHERE ua.user_id = user_uuid
                AND ua.allergen = ANY(d.allergens)
            )
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

COMMENT ON FUNCTION public.get_menu_dishes IS 'Returns menu dishes with protein options from ingredients table, ordering window validation, and nutrition visibility toggle';

-- ============================================================================
-- Function: validate_cart_item_protein
-- Validates that selected protein is available for the dish
-- ============================================================================
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

COMMENT ON FUNCTION public.validate_cart_item_protein IS 'Validates protein selection against dish available protein ingredients';

-- ============================================================================
-- PART 5: RECREATE TRIGGERS FOR CART VALIDATION
-- ============================================================================

-- Drop old triggers if they exist
DROP TRIGGER IF EXISTS validate_cart_item_protein_trigger ON public.cart_items;
DROP TRIGGER IF EXISTS validate_guest_cart_item_protein_trigger ON public.guest_cart_items;

-- Create triggers for cart items validation
CREATE TRIGGER validate_cart_item_protein_trigger
    BEFORE INSERT OR UPDATE ON public.cart_items
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_cart_item_protein();

CREATE TRIGGER validate_guest_cart_item_protein_trigger
    BEFORE INSERT OR UPDATE ON public.guest_cart_items
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_cart_item_protein();

-- ============================================================================
-- PART 6: GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION public.get_dish_protein_options(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_menu_dishes(UUID, UUID) TO authenticated;

-- ============================================================================
-- PART 7: ADD HELPFUL COMMENTS
-- ============================================================================

COMMENT ON TABLE public.dish_protein_options IS 'Junction table connecting dishes to protein ingredient options from the ingredients table (where category=protein)';
COMMENT ON COLUMN public.dish_protein_options.ingredient_id IS 'References ingredients table where category=protein - these are the available protein options for the dish';

-- ============================================================================
-- CLEANUP NOTES
-- ============================================================================
-- After verifying everything works correctly, you can optionally run:
-- DROP TABLE IF EXISTS public.dish_protein_options_backup CASCADE;
-- DROP TABLE IF EXISTS public.protein_options CASCADE;
-- 
-- The protein_options table is no longer needed as proteins are now managed
-- as ingredients with category='protein'
-- ============================================================================

-- Migration complete!
SELECT 'Migration completed successfully! Ingredients enhanced, protein options refactored to use ingredients table.' AS status;
