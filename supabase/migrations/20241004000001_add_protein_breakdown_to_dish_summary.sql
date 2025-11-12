-- Add protein option breakdown to dish summary
-- This migration updates get_weekly_dish_summary to show protein options instead of total orders

-- Drop existing function
DROP FUNCTION IF EXISTS public.get_weekly_dish_summary(DATE, DATE) CASCADE;

-- Recreate get_weekly_dish_summary with protein option breakdown
CREATE OR REPLACE FUNCTION public.get_weekly_dish_summary(
    start_date DATE DEFAULT CURRENT_DATE,
    end_date DATE DEFAULT CURRENT_DATE + INTERVAL '7 days'
)
RETURNS TABLE (
    dish_id UUID,
    dish_name TEXT,
    total_quantity INTEGER,
    pending_quantity INTEGER,
    cooking_quantity INTEGER,
    cooked_quantity INTEGER,
    protein_breakdown JSONB,  -- Changed from total_orders to protein_breakdown
    cooking_status TEXT,
    batch_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id as dish_id,
        d.name as dish_name,
        SUM(oi.quantity)::INTEGER as total_quantity,
        SUM(CASE WHEN oi.cooking_status = 'pending' THEN oi.quantity ELSE 0 END)::INTEGER as pending_quantity,
        SUM(CASE WHEN oi.cooking_status = 'cooking' THEN oi.quantity ELSE 0 END)::INTEGER as cooking_quantity,
        SUM(CASE WHEN oi.cooking_status = 'cooked' THEN oi.quantity ELSE 0 END)::INTEGER as cooked_quantity,
        -- Aggregate protein options with their quantities
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'protein', COALESCE(protein_option, 'No protein'),
                    'quantity', protein_quantity,
                    'pending', pending_qty,
                    'cooking', cooking_qty,
                    'cooked', cooked_qty
                )
                ORDER BY protein_quantity DESC
            )
            FROM (
                SELECT 
                    COALESCE(oi2.protein_option, 'No protein') as protein_option,
                    SUM(oi2.quantity)::INTEGER as protein_quantity,
                    SUM(CASE WHEN oi2.cooking_status = 'pending' THEN oi2.quantity ELSE 0 END)::INTEGER as pending_qty,
                    SUM(CASE WHEN oi2.cooking_status = 'cooking' THEN oi2.quantity ELSE 0 END)::INTEGER as cooking_qty,
                    SUM(CASE WHEN oi2.cooking_status = 'cooked' THEN oi2.quantity ELSE 0 END)::INTEGER as cooked_qty
                FROM public.order_items oi2
                JOIN public.orders o2 ON oi2.order_id = o2.id
                WHERE oi2.dish_id = d.id
                AND o2.delivery_date BETWEEN start_date AND end_date
                AND o2.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery')
                GROUP BY COALESCE(oi2.protein_option, 'No protein')
            ) protein_summary
        ) as protein_breakdown,
        CASE 
            WHEN SUM(CASE WHEN oi.cooking_status = 'cooked' THEN oi.quantity ELSE 0 END) = SUM(oi.quantity) THEN 'completed'
            WHEN SUM(CASE WHEN oi.cooking_status = 'cooking' THEN oi.quantity ELSE 0 END) > 0 THEN 'cooking'
            ELSE 'pending'
        END as cooking_status,
        dcb.id as batch_id
    FROM public.dishes d
    JOIN public.order_items oi ON d.id = oi.dish_id
    JOIN public.orders o ON oi.order_id = o.id
    LEFT JOIN public.dish_cooking_batches dcb ON d.id = dcb.dish_id 
        AND o.delivery_date = dcb.batch_date
    WHERE o.delivery_date BETWEEN start_date AND end_date
    AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery')
    GROUP BY d.id, d.name, dcb.id
    ORDER BY total_quantity DESC, d.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_weekly_dish_summary(DATE, DATE) TO authenticated;

-- Add comment
COMMENT ON FUNCTION public.get_weekly_dish_summary IS 'Returns dish summary with protein option breakdown for cooking dashboard';
