-- Add function to calculate dish nutrition including selected protein option
-- This function extends get_dish_nutrition to include a specific protein ingredient
-- Created: 2024-11-04

CREATE OR REPLACE FUNCTION public.get_dish_nutrition_with_protein(
    p_dish_id UUID,
    p_protein_name TEXT
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
    vitamin_d DECIMAL(10,2),
    vitamin_c DECIMAL(10,2),
    vitamin_b9 DECIMAL(10,2),
    vitamin_b12 DECIMAL(10,2),
    potassium DECIMAL(10,2),
    calcium DECIMAL(10,2),
    magnesium DECIMAL(10,2),
    iron DECIMAL(10,2),
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
    v_vitamin_d DECIMAL(10,2) := 0;
    v_vitamin_c DECIMAL(10,2) := 0;
    v_vitamin_b9 DECIMAL(10,2) := 0;
    v_vitamin_b12 DECIMAL(10,2) := 0;
    v_potassium DECIMAL(10,2) := 0;
    v_calcium DECIMAL(10,2) := 0;
    v_magnesium DECIMAL(10,2) := 0;
    v_iron DECIMAL(10,2) := 0;
    v_is_vegan BOOLEAN := true;
    v_is_vegetarian BOOLEAN := true;
    v_is_gluten_free BOOLEAN := true;
    v_allergens TEXT[] := ARRAY[]::TEXT[];
    ingredient_record RECORD;
BEGIN
    -- Loop through all base ingredients in the dish (from dish_ingredients)
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
            i.vitamin_d_per_100g,
            i.vitamin_c_per_100g,
            i.vitamin_b9_per_100g,
            i.vitamin_b12_per_100g,
            i.potassium_per_100g,
            i.calcium_per_100g,
            i.magnesium_per_100g,
            i.iron_per_100g,
            i.is_vegan,
            i.is_vegetarian,
            i.is_gluten_free,
            i.common_allergens
        FROM public.dish_ingredients di
        JOIN public.ingredients i ON di.ingredient_id = i.id
        WHERE di.dish_id = p_dish_id
    LOOP
        -- Convert quantity to grams
        DECLARE
            quantity_in_grams DECIMAL(10,2);
        BEGIN
            CASE ingredient_record.unit
                WHEN 'kg' THEN quantity_in_grams := ingredient_record.quantity * 1000;
                WHEN 'l' THEN quantity_in_grams := ingredient_record.quantity * 1000;
                WHEN 'ml' THEN quantity_in_grams := ingredient_record.quantity;
                WHEN 'g' THEN quantity_in_grams := ingredient_record.quantity;
                ELSE quantity_in_grams := ingredient_record.quantity;
            END CASE;
            
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
            IF ingredient_record.vitamin_d_per_100g IS NOT NULL THEN
                v_vitamin_d := v_vitamin_d + (ingredient_record.vitamin_d_per_100g * quantity_in_grams / 100);
            END IF;
            IF ingredient_record.vitamin_c_per_100g IS NOT NULL THEN
                v_vitamin_c := v_vitamin_c + (ingredient_record.vitamin_c_per_100g * quantity_in_grams / 100);
            END IF;
            IF ingredient_record.vitamin_b9_per_100g IS NOT NULL THEN
                v_vitamin_b9 := v_vitamin_b9 + (ingredient_record.vitamin_b9_per_100g * quantity_in_grams / 100);
            END IF;
            IF ingredient_record.vitamin_b12_per_100g IS NOT NULL THEN
                v_vitamin_b12 := v_vitamin_b12 + (ingredient_record.vitamin_b12_per_100g * quantity_in_grams / 100);
            END IF;
            IF ingredient_record.potassium_per_100g IS NOT NULL THEN
                v_potassium := v_potassium + (ingredient_record.potassium_per_100g * quantity_in_grams / 100);
            END IF;
            IF ingredient_record.calcium_per_100g IS NOT NULL THEN
                v_calcium := v_calcium + (ingredient_record.calcium_per_100g * quantity_in_grams / 100);
            END IF;
            IF ingredient_record.magnesium_per_100g IS NOT NULL THEN
                v_magnesium := v_magnesium + (ingredient_record.magnesium_per_100g * quantity_in_grams / 100);
            END IF;
            IF ingredient_record.iron_per_100g IS NOT NULL THEN
                v_iron := v_iron + (ingredient_record.iron_per_100g * quantity_in_grams / 100);
            END IF;
            
            -- Update dietary flags
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
    
    -- Now add the selected protein option from dish_protein_options
    IF p_protein_name IS NOT NULL AND p_protein_name != '' THEN
        FOR ingredient_record IN
            SELECT 
                dpo.quantity,
                dpo.unit,
                i.calories_per_100g,
                i.protein_per_100g,
                i.carbs_per_100g,
                i.fat_per_100g,
                i.saturated_fat_per_100g,
                i.fiber_per_100g,
                i.sugar_per_100g,
                i.sodium_per_100g,
                i.vitamin_d_per_100g,
                i.vitamin_c_per_100g,
                i.vitamin_b9_per_100g,
                i.vitamin_b12_per_100g,
                i.potassium_per_100g,
                i.calcium_per_100g,
                i.magnesium_per_100g,
                i.iron_per_100g,
                i.is_vegan,
                i.is_vegetarian,
                i.is_gluten_free,
                i.common_allergens
            FROM public.dish_protein_options dpo
            JOIN public.ingredients i ON dpo.ingredient_id = i.id
            WHERE dpo.dish_id = p_dish_id
            AND i.name = p_protein_name
            AND i.category = 'protein'
        LOOP
            -- Convert quantity to grams
            DECLARE
                quantity_in_grams DECIMAL(10,2);
            BEGIN
                CASE ingredient_record.unit
                    WHEN 'kg' THEN quantity_in_grams := ingredient_record.quantity * 1000;
                    WHEN 'l' THEN quantity_in_grams := ingredient_record.quantity * 1000;
                    WHEN 'ml' THEN quantity_in_grams := ingredient_record.quantity;
                    WHEN 'g' THEN quantity_in_grams := ingredient_record.quantity;
                    ELSE quantity_in_grams := ingredient_record.quantity;
                END CASE;
                
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
                IF ingredient_record.vitamin_d_per_100g IS NOT NULL THEN
                    v_vitamin_d := v_vitamin_d + (ingredient_record.vitamin_d_per_100g * quantity_in_grams / 100);
                END IF;
                IF ingredient_record.vitamin_c_per_100g IS NOT NULL THEN
                    v_vitamin_c := v_vitamin_c + (ingredient_record.vitamin_c_per_100g * quantity_in_grams / 100);
                END IF;
                IF ingredient_record.vitamin_b9_per_100g IS NOT NULL THEN
                    v_vitamin_b9 := v_vitamin_b9 + (ingredient_record.vitamin_b9_per_100g * quantity_in_grams / 100);
                END IF;
                IF ingredient_record.vitamin_b12_per_100g IS NOT NULL THEN
                    v_vitamin_b12 := v_vitamin_b12 + (ingredient_record.vitamin_b12_per_100g * quantity_in_grams / 100);
                END IF;
                IF ingredient_record.potassium_per_100g IS NOT NULL THEN
                    v_potassium := v_potassium + (ingredient_record.potassium_per_100g * quantity_in_grams / 100);
                END IF;
                IF ingredient_record.calcium_per_100g IS NOT NULL THEN
                    v_calcium := v_calcium + (ingredient_record.calcium_per_100g * quantity_in_grams / 100);
                END IF;
                IF ingredient_record.magnesium_per_100g IS NOT NULL THEN
                    v_magnesium := v_magnesium + (ingredient_record.magnesium_per_100g * quantity_in_grams / 100);
                END IF;
                IF ingredient_record.iron_per_100g IS NOT NULL THEN
                    v_iron := v_iron + (ingredient_record.iron_per_100g * quantity_in_grams / 100);
                END IF;
                
                -- Update dietary flags
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
    END IF;
    
    -- Remove duplicate allergens
    v_allergens := ARRAY(SELECT DISTINCT unnest(v_allergens));
    
    -- Return the calculated nutrition facts
    RETURN QUERY SELECT 
        v_calories,
        v_protein,
        v_carbs,
        v_fat,
        v_saturated_fat,
        v_fiber,
        v_sugar,
        v_sodium,
        v_vitamin_d,
        v_vitamin_c,
        v_vitamin_b9,
        v_vitamin_b12,
        v_potassium,
        v_calcium,
        v_magnesium,
        v_iron,
        v_total_weight,
        v_is_vegan,
        v_is_vegetarian,
        v_is_gluten_free,
        v_allergens;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_dish_nutrition_with_protein(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dish_nutrition_with_protein(UUID, TEXT) TO anon;

-- Add comment
COMMENT ON FUNCTION public.get_dish_nutrition_with_protein IS 'Calculates comprehensive nutrition facts for a dish including a selected protein option. Returns per-serving nutrition information with the specified protein ingredient included in calculations.';
