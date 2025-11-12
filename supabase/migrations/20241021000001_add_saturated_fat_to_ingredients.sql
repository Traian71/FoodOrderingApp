-- Migration: Add saturated fat field to ingredients table for EU nutrition label compliance
-- This adds saturated_fat_per_100g column to track saturated fat content

-- Add saturated_fat_per_100g column to ingredients table
ALTER TABLE public.ingredients
ADD COLUMN saturated_fat_per_100g DECIMAL(6,2);

-- Add comment
COMMENT ON COLUMN public.ingredients.saturated_fat_per_100g IS 'Saturated fat content per 100g in grams (required for EU nutrition labels)';

-- Update the get_dish_nutrition function to include saturated fat
CREATE OR REPLACE FUNCTION public.get_dish_nutrition(
    p_dish_id UUID
)
RETURNS TABLE (
    calories DECIMAL(10,2),
    protein DECIMAL(10,2),
    carbs DECIMAL(10,2),
    fat DECIMAL(10,2),
    saturated_fat DECIMAL(10,2),
    fiber DECIMAL(10,2),
    sugar DECIMAL(10,2),
    sodium DECIMAL(10,2),
    total_weight DECIMAL(10,2),
    is_vegan BOOLEAN,
    is_vegetarian BOOLEAN,
    is_gluten_free BOOLEAN,
    allergens TEXT[]
) AS $$
DECLARE
    v_total_weight DECIMAL(10,2) := 0;
    v_calories DECIMAL(10,2) := 0;
    v_protein DECIMAL(10,2) := 0;
    v_carbs DECIMAL(10,2) := 0;
    v_fat DECIMAL(10,2) := 0;
    v_saturated_fat DECIMAL(10,2) := 0;
    v_fiber DECIMAL(10,2) := 0;
    v_sugar DECIMAL(10,2) := 0;
    v_sodium DECIMAL(10,2) := 0;
    v_is_vegan BOOLEAN := true;
    v_is_vegetarian BOOLEAN := true;
    v_is_gluten_free BOOLEAN := true;
    v_allergens TEXT[] := ARRAY[]::TEXT[];
    ingredient_record RECORD;
BEGIN
    -- Loop through all ingredients in the dish
    FOR ingredient_record IN
        SELECT 
            di.quantity,
            di.unit,
            i.calories_per_100g,
            i.protein_per_100g,
            i.carbs_per_100g,
            i.fat_per_100g,
            i.saturated_fat_per_100g,
            i.fiber_per_100g,
            i.sugar_per_100g,
            i.sodium_per_100g,
            i.is_vegan,
            i.is_vegetarian,
            i.is_gluten_free,
            i.common_allergens
        FROM public.dish_ingredients di
        JOIN public.ingredients i ON di.ingredient_id = i.id
        WHERE di.dish_id = p_dish_id
    LOOP
        -- Convert quantity to grams (assuming most units are in grams or ml which is roughly equivalent)
        -- For simplicity, we assume the unit is already in grams/ml
        -- In a production system, you'd want proper unit conversion
        DECLARE
            quantity_in_grams DECIMAL(10,2);
        BEGIN
            -- Simple unit conversion (you can expand this)
            CASE ingredient_record.unit
                WHEN 'kg' THEN quantity_in_grams := ingredient_record.quantity * 1000;
                WHEN 'l' THEN quantity_in_grams := ingredient_record.quantity * 1000;
                WHEN 'ml' THEN quantity_in_grams := ingredient_record.quantity;
                WHEN 'g' THEN quantity_in_grams := ingredient_record.quantity;
                ELSE quantity_in_grams := ingredient_record.quantity; -- Default assume grams
            END CASE;
            
            -- Add to total weight
            v_total_weight := v_total_weight + quantity_in_grams;
            
            -- Calculate nutrition based on per 100g values
            IF ingredient_record.calories_per_100g IS NOT NULL THEN
                v_calories := v_calories + (ingredient_record.calories_per_100g * quantity_in_grams / 100);
            END IF;
            
            IF ingredient_record.protein_per_100g IS NOT NULL THEN
                v_protein := v_protein + (ingredient_record.protein_per_100g * quantity_in_grams / 100);
            END IF;
            
            IF ingredient_record.carbs_per_100g IS NOT NULL THEN
                v_carbs := v_carbs + (ingredient_record.carbs_per_100g * quantity_in_grams / 100);
            END IF;
            
            IF ingredient_record.fat_per_100g IS NOT NULL THEN
                v_fat := v_fat + (ingredient_record.fat_per_100g * quantity_in_grams / 100);
            END IF;
            
            IF ingredient_record.saturated_fat_per_100g IS NOT NULL THEN
                v_saturated_fat := v_saturated_fat + (ingredient_record.saturated_fat_per_100g * quantity_in_grams / 100);
            END IF;
            
            IF ingredient_record.fiber_per_100g IS NOT NULL THEN
                v_fiber := v_fiber + (ingredient_record.fiber_per_100g * quantity_in_grams / 100);
            END IF;
            
            IF ingredient_record.sugar_per_100g IS NOT NULL THEN
                v_sugar := v_sugar + (ingredient_record.sugar_per_100g * quantity_in_grams / 100);
            END IF;
            
            IF ingredient_record.sodium_per_100g IS NOT NULL THEN
                v_sodium := v_sodium + (ingredient_record.sodium_per_100g * quantity_in_grams / 100);
            END IF;
            
            -- Check dietary flags (if any ingredient is not vegan, dish is not vegan)
            IF NOT ingredient_record.is_vegan THEN
                v_is_vegan := false;
            END IF;
            
            IF NOT ingredient_record.is_vegetarian THEN
                v_is_vegetarian := false;
            END IF;
            
            IF NOT ingredient_record.is_gluten_free THEN
                v_is_gluten_free := false;
            END IF;
            
            -- Collect allergens
            IF ingredient_record.common_allergens IS NOT NULL THEN
                v_allergens := array_cat(v_allergens, ingredient_record.common_allergens);
            END IF;
        END;
    END LOOP;
    
    -- Remove duplicate allergens
    v_allergens := ARRAY(SELECT DISTINCT unnest(v_allergens) ORDER BY 1);
    
    -- Return the calculated nutrition facts
    RETURN QUERY SELECT 
        ROUND(v_calories, 2),
        ROUND(v_protein, 2),
        ROUND(v_carbs, 2),
        ROUND(v_fat, 2),
        ROUND(v_saturated_fat, 2),
        ROUND(v_fiber, 2),
        ROUND(v_sugar, 2),
        ROUND(v_sodium, 2),
        ROUND(v_total_weight, 2),
        v_is_vegan,
        v_is_vegetarian,
        v_is_gluten_free,
        v_allergens;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_dish_nutrition(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dish_nutrition(UUID) TO anon;

-- Add comment
COMMENT ON FUNCTION public.get_dish_nutrition IS 'Calculates nutrition facts for a dish based on its recipe ingredients. Returns per-serving nutrition information including saturated fat for EU compliance.';
