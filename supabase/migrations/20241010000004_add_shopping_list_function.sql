-- Add shopping list generation function
-- This function calculates ingredient quantities needed based on actual orders

-- Function to generate shopping list for a specific date range
CREATE OR REPLACE FUNCTION public.get_shopping_list(
    start_date DATE,
    end_date DATE,
    p_delivery_group delivery_group DEFAULT NULL
)
RETURNS TABLE (
    ingredient_id UUID,
    ingredient_name TEXT,
    ingredient_category TEXT,
    total_quantity DECIMAL(10,2),
    unit TEXT,
    dish_count BIGINT,
    dishes_using JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH order_dish_quantities AS (
        -- Get all order items with their quantities for the date range
        SELECT 
            oi.dish_id,
            oi.protein_option,
            SUM(oi.quantity) as total_orders
        FROM public.order_items oi
        JOIN public.orders o ON oi.order_id = o.id
        WHERE o.delivery_date BETWEEN start_date AND end_date
        AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery')
        AND (p_delivery_group IS NULL OR o.delivery_group = p_delivery_group)
        GROUP BY oi.dish_id, oi.protein_option
    ),
    ingredient_calculations AS (
        -- Calculate ingredient quantities needed
        SELECT 
            di.ingredient_id,
            i.name as ingredient_name,
            i.category as ingredient_category,
            di.unit,
            -- Multiply recipe quantity by number of orders
            SUM(di.quantity * odq.total_orders) as total_quantity,
            -- Track which dishes use this ingredient
            jsonb_agg(
                jsonb_build_object(
                    'dish_id', d.id,
                    'dish_name', d.name,
                    'protein_option', odq.protein_option,
                    'orders', odq.total_orders,
                    'quantity_per_dish', di.quantity,
                    'total_needed', di.quantity * odq.total_orders
                )
                ORDER BY d.name
            ) as dishes_using,
            COUNT(DISTINCT d.id) as dish_count
        FROM order_dish_quantities odq
        JOIN public.dishes d ON odq.dish_id = d.id
        JOIN public.dish_ingredients di ON d.id = di.dish_id
        JOIN public.ingredients i ON di.ingredient_id = i.id
        GROUP BY di.ingredient_id, i.name, i.category, di.unit
    )
    SELECT 
        ic.ingredient_id,
        ic.ingredient_name,
        ic.ingredient_category,
        ROUND(ic.total_quantity, 2) as total_quantity,
        ic.unit,
        ic.dish_count,
        ic.dishes_using
    FROM ingredient_calculations ic
    ORDER BY 
        ic.ingredient_category NULLS LAST,
        ic.ingredient_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get shopping list summary by dish (for batch cooking view)
CREATE OR REPLACE FUNCTION public.get_shopping_list_by_dish(
    start_date DATE,
    end_date DATE,
    p_delivery_group delivery_group DEFAULT NULL
)
RETURNS TABLE (
    dish_id UUID,
    dish_name TEXT,
    protein_option TEXT,
    total_orders INTEGER,
    ingredients JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH order_dish_quantities AS (
        -- Get all order items with their quantities for the date range
        SELECT 
            oi.dish_id,
            oi.protein_option,
            SUM(oi.quantity) as total_orders
        FROM public.order_items oi
        JOIN public.orders o ON oi.order_id = o.id
        WHERE o.delivery_date BETWEEN start_date AND end_date
        AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery')
        AND (p_delivery_group IS NULL OR o.delivery_group = p_delivery_group)
        GROUP BY oi.dish_id, oi.protein_option
    ),
    dish_ingredients_calculated AS (
        SELECT 
            odq.dish_id,
            d.name as dish_name,
            odq.protein_option,
            odq.total_orders,
            jsonb_agg(
                jsonb_build_object(
                    'ingredient_id', i.id,
                    'ingredient_name', i.name,
                    'category', i.category,
                    'quantity_per_dish', di.quantity,
                    'unit', di.unit,
                    'total_quantity', di.quantity * odq.total_orders,
                    'preparation_note', di.preparation_note
                )
                ORDER BY i.category NULLS LAST, i.name
            ) as ingredients
        FROM order_dish_quantities odq
        JOIN public.dishes d ON odq.dish_id = d.id
        JOIN public.dish_ingredients di ON d.id = di.dish_id
        JOIN public.ingredients i ON di.ingredient_id = i.id
        GROUP BY odq.dish_id, d.name, odq.protein_option, odq.total_orders
    )
    SELECT 
        dic.dish_id,
        dic.dish_name,
        dic.protein_option,
        dic.total_orders::INTEGER,
        dic.ingredients
    FROM dish_ingredients_calculated dic
    ORDER BY dic.dish_name, dic.protein_option NULLS FIRST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users (admin only via RLS)
GRANT EXECUTE ON FUNCTION public.get_shopping_list(DATE, DATE, delivery_group) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_shopping_list_by_dish(DATE, DATE, delivery_group) TO authenticated;

-- Add comments
COMMENT ON FUNCTION public.get_shopping_list IS 'Generates a shopping list with total ingredient quantities needed for orders in a date range';
COMMENT ON FUNCTION public.get_shopping_list_by_dish IS 'Generates a shopping list organized by dish, showing ingredients needed for each dish batch';
