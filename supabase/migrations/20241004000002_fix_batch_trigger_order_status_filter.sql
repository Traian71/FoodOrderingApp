-- Fix batch cooking triggers to only affect confirmed orders
-- This ensures pending orders are not affected when starting/completing dish batches

-- Drop and recreate BOTH trigger functions with proper order status filtering
DROP FUNCTION IF EXISTS public.update_order_items_on_batch_completion() CASCADE;
DROP FUNCTION IF EXISTS public.update_order_items_after_batch_change() CASCADE;

-- Recreate BEFORE trigger function with order status filter
CREATE OR REPLACE FUNCTION public.update_order_items_on_batch_completion()
RETURNS TRIGGER AS $$
BEGIN
    -- When a batch is marked as completed, update all order items for that dish on that date
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        UPDATE public.order_items oi
        SET 
            cooking_status = 'cooked',
            cooking_completed_at = NOW()
        FROM public.orders o
        WHERE oi.order_id = o.id
        AND oi.dish_id = NEW.dish_id
        AND o.delivery_date = NEW.batch_date
        AND oi.cooking_status != 'cooked'
        -- CRITICAL FIX: Only affect confirmed orders, not pending ones
        AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery');
        
        -- Update batch completion timestamp
        NEW.completed_at = NOW();
    END IF;
    
    -- When a batch is marked as cooking, update order items to cooking status
    IF NEW.status = 'cooking' AND (OLD.status IS NULL OR OLD.status != 'cooking') THEN
        UPDATE public.order_items oi
        SET 
            cooking_status = 'cooking',
            cooking_started_at = NOW()
        FROM public.orders o
        WHERE oi.order_id = o.id
        AND oi.dish_id = NEW.dish_id
        AND o.delivery_date = NEW.batch_date
        AND oi.cooking_status = 'pending'
        -- CRITICAL FIX: Only affect confirmed orders, not pending ones
        AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery');
        
        -- Update batch start timestamp
        NEW.started_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.update_order_items_after_batch_change()
RETURNS TRIGGER AS $$
BEGIN
    -- When a batch is created or updated with 'cooking' status
    IF NEW.status = 'cooking' THEN
        UPDATE public.order_items oi
        SET 
            cooking_status = 'cooking',
            cooking_started_at = COALESCE(oi.cooking_started_at, NOW())
        FROM public.orders o
        WHERE oi.order_id = o.id
        AND oi.dish_id = NEW.dish_id
        AND o.delivery_date = NEW.batch_date
        AND oi.cooking_status = 'pending'
        -- CRITICAL FIX: Only affect confirmed orders, not pending ones
        AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery');
        
        RAISE NOTICE 'Updated % order items to cooking status for dish % on date %', 
            (SELECT COUNT(*) FROM public.order_items oi 
             JOIN public.orders o ON oi.order_id = o.id 
             WHERE oi.dish_id = NEW.dish_id 
             AND o.delivery_date = NEW.batch_date 
             AND oi.cooking_status = 'cooking'
             AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery')), 
            NEW.dish_id, NEW.batch_date;
    END IF;
    
    -- When a batch is marked as completed
    IF NEW.status = 'completed' THEN
        UPDATE public.order_items oi
        SET 
            cooking_status = 'cooked',
            cooking_completed_at = COALESCE(oi.cooking_completed_at, NOW())
        FROM public.orders o
        WHERE oi.order_id = o.id
        AND oi.dish_id = NEW.dish_id
        AND o.delivery_date = NEW.batch_date
        AND oi.cooking_status != 'cooked'
        -- CRITICAL FIX: Only affect confirmed orders, not pending ones
        AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery');
        
        RAISE NOTICE 'Updated % order items to cooked status for dish % on date %', 
            (SELECT COUNT(*) FROM public.order_items oi 
             JOIN public.orders o ON oi.order_id = o.id 
             WHERE oi.dish_id = NEW.dish_id 
             AND o.delivery_date = NEW.batch_date 
             AND oi.cooking_status = 'cooked'
             AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery')), 
            NEW.dish_id, NEW.batch_date;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER update_order_items_after_batch_change_trigger
    AFTER INSERT OR UPDATE ON public.dish_cooking_batches
    FOR EACH ROW EXECUTE FUNCTION update_order_items_after_batch_change();

-- Add comment
COMMENT ON FUNCTION public.update_order_items_after_batch_change IS 'Updates order item cooking status only for confirmed orders when batch status changes';
