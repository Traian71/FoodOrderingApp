-- Fix start_dish_cooking_batch to validate quantity before inserting
-- This prevents the constraint violation error

DROP FUNCTION IF EXISTS start_dish_cooking_batch(UUID, DATE);

CREATE OR REPLACE FUNCTION start_dish_cooking_batch(
    p_dish_id UUID,
    p_batch_date DATE DEFAULT CURRENT_DATE
)
RETURNS UUID AS $$
DECLARE
    batch_id UUID;
    total_qty INTEGER;
BEGIN
    -- Calculate total quantity needed for this dish on this date
    SELECT COALESCE(SUM(oi.quantity), 0) INTO total_qty
    FROM public.order_items oi
    JOIN public.orders o ON oi.order_id = o.id
    WHERE oi.dish_id = p_dish_id
    AND o.delivery_date = p_batch_date
    AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery');
    
    -- Log for debugging
    RAISE NOTICE 'Dish ID: %, Batch Date: %, Total Quantity: %', p_dish_id, p_batch_date, total_qty;
    
    -- Validate that we have orders to cook
    IF total_qty = 0 THEN
        RAISE EXCEPTION 'No orders found for dish % on date %. Cannot start cooking batch.', p_dish_id, p_batch_date
            USING HINT = 'Make sure there are confirmed orders with this dish for the specified delivery date.';
    END IF;
    
    -- Create or update cooking batch
    INSERT INTO public.dish_cooking_batches (dish_id, batch_date, total_quantity, status)
    VALUES (p_dish_id, p_batch_date, total_qty, 'cooking')
    ON CONFLICT (dish_id, batch_date) 
    DO UPDATE SET 
        status = 'cooking',
        total_quantity = total_qty,
        updated_at = NOW()
    RETURNING id INTO batch_id;
    
    RETURN batch_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Also update complete_dish_cooking_batch with similar validation
DROP FUNCTION IF EXISTS complete_dish_cooking_batch(UUID, DATE);

CREATE OR REPLACE FUNCTION complete_dish_cooking_batch(
    p_dish_id UUID,
    p_batch_date DATE DEFAULT CURRENT_DATE
)
RETURNS BOOLEAN AS $$
DECLARE
    rows_affected INTEGER;
    total_qty INTEGER;
BEGIN
    -- Calculate total quantity
    SELECT COALESCE(SUM(oi.quantity), 0) INTO total_qty
    FROM public.order_items oi
    JOIN public.orders o ON oi.order_id = o.id
    WHERE oi.dish_id = p_dish_id
    AND o.delivery_date = p_batch_date
    AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery');
    
    -- Validate that we have orders
    IF total_qty = 0 THEN
        RAISE EXCEPTION 'No orders found for dish % on date %. Cannot complete cooking batch.', p_dish_id, p_batch_date
            USING HINT = 'Make sure there are confirmed orders with this dish for the specified delivery date.';
    END IF;
    
    -- Update cooking batch to completed
    UPDATE public.dish_cooking_batches
    SET status = 'completed', updated_at = NOW()
    WHERE dish_id = p_dish_id AND batch_date = p_batch_date;
    
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    -- If no batch exists, create one and mark as completed
    IF rows_affected = 0 THEN
        INSERT INTO public.dish_cooking_batches (dish_id, batch_date, total_quantity, status)
        VALUES (p_dish_id, p_batch_date, total_qty, 'completed');
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION start_dish_cooking_batch(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION complete_dish_cooking_batch(UUID, DATE) TO authenticated;
