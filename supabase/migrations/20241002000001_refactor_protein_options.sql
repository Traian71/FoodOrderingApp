-- Refactor protein options from array to relational tables
-- This migration creates protein_options and dish_protein_options tables

-- Create protein_options table
CREATE TABLE public.protein_options (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT protein_options_name_check CHECK (length(name) > 0),
    CONSTRAINT protein_options_display_order_check CHECK (display_order >= 0)
);

-- Create dish_protein_options junction table
CREATE TABLE public.dish_protein_options (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    dish_id UUID REFERENCES public.dishes(id) ON DELETE CASCADE NOT NULL,
    protein_option_id UUID REFERENCES public.protein_options(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(dish_id, protein_option_id)
);

-- Create indexes for performance
CREATE INDEX idx_protein_options_active ON public.protein_options(is_active);
CREATE INDEX idx_protein_options_display_order ON public.protein_options(display_order);
CREATE INDEX idx_dish_protein_options_dish_id ON public.dish_protein_options(dish_id);
CREATE INDEX idx_dish_protein_options_protein_id ON public.dish_protein_options(protein_option_id);

-- Insert default protein options (migrating from hardcoded values)
INSERT INTO public.protein_options (name, description, display_order) VALUES
('Chicken', 'Lean poultry protein', 1),
('Beef', 'Red meat option', 2),
('Pork', 'Tender pork cuts', 3),
('Fish', 'Fresh fish fillets', 4),
('Tofu', 'Plant-based protein', 5),
('Tempeh', 'Fermented soy protein', 6),
('Shrimp', 'Seafood option', 7);

-- Migrate existing data from available_protein_options array to new tables
-- This will create dish_protein_options entries for dishes that have protein options
DO $$
DECLARE
    dish_record RECORD;
    protein_name TEXT;
    protein_id UUID;
BEGIN
    -- Loop through all dishes that have protein options
    FOR dish_record IN 
        SELECT id, available_protein_options 
        FROM public.dishes 
        WHERE available_protein_options IS NOT NULL 
        AND array_length(available_protein_options, 1) > 0
    LOOP
        -- Loop through each protein option in the array
        FOREACH protein_name IN ARRAY dish_record.available_protein_options
        LOOP
            -- Find the protein option ID (case-insensitive match)
            SELECT id INTO protein_id 
            FROM public.protein_options 
            WHERE LOWER(name) = LOWER(protein_name)
            LIMIT 1;
            
            -- If found, create the relationship
            IF protein_id IS NOT NULL THEN
                INSERT INTO public.dish_protein_options (dish_id, protein_option_id)
                VALUES (dish_record.id, protein_id)
                ON CONFLICT (dish_id, protein_option_id) DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- Drop the old available_protein_options column from dishes table
ALTER TABLE public.dishes DROP COLUMN IF EXISTS available_protein_options;

-- Update the validate_cart_item_protein function to use new tables
DROP FUNCTION IF EXISTS public.validate_cart_item_protein() CASCADE;

CREATE OR REPLACE FUNCTION public.validate_cart_item_protein()
RETURNS TRIGGER AS $$
BEGIN
    -- If protein option is specified, validate it exists for this dish
    IF NEW.protein_option IS NOT NULL AND NEW.protein_option != '' THEN
        IF NOT EXISTS (
            SELECT 1 
            FROM public.dish_protein_options dpo
            JOIN public.protein_options po ON po.id = dpo.protein_option_id
            WHERE dpo.dish_id = NEW.dish_id
            AND po.name = NEW.protein_option
            AND po.is_active = true
        ) THEN
            RAISE EXCEPTION 'Invalid protein option "%" for dish id %', NEW.protein_option, NEW.dish_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers for cart items validation
CREATE TRIGGER validate_cart_item_protein_trigger
    BEFORE INSERT OR UPDATE ON public.cart_items
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_cart_item_protein();

CREATE TRIGGER validate_guest_cart_item_protein_trigger
    BEFORE INSERT OR UPDATE ON public.guest_cart_items
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_cart_item_protein();

-- Update get_menu_dishes function to include protein options from new tables
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
    can_order BOOLEAN
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
        END as can_order
    FROM public.dishes d
    INNER JOIN public.menu_items mi ON mi.dish_id = d.id
    WHERE mi.menu_month_id = menu_month_uuid
    AND d.is_active = true
    ORDER BY mi.display_order, d.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add RLS policies for protein_options and dish_protein_options tables
ALTER TABLE public.protein_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dish_protein_options ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read protein options
CREATE POLICY "Allow read access to protein options"
    ON public.protein_options FOR SELECT
    TO authenticated
    USING (true);

-- Allow all authenticated users to read dish protein options
CREATE POLICY "Allow read access to dish protein options"
    ON public.dish_protein_options FOR SELECT
    TO authenticated
    USING (true);

-- Allow admin users to manage protein options
CREATE POLICY "Allow admin users to manage protein options"
    ON public.protein_options FOR ALL
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

-- Create helper function to get dish protein options
CREATE OR REPLACE FUNCTION public.get_dish_protein_options(dish_uuid UUID)
RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    display_order INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        po.id,
        po.name,
        po.description,
        po.display_order
    FROM public.protein_options po
    INNER JOIN public.dish_protein_options dpo ON dpo.protein_option_id = po.id
    WHERE dpo.dish_id = dish_uuid
    AND po.is_active = true
    ORDER BY po.display_order;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
