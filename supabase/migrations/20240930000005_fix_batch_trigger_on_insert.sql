-- Fix the trigger to fire on both INSERT and UPDATE
-- This ensures order_items are updated when a batch is first created

DROP TRIGGER IF EXISTS update_order_items_on_batch_completion_trigger ON public.dish_cooking_batches;

-- Recreate the trigger to fire on INSERT OR UPDATE
CREATE TRIGGER update_order_items_on_batch_completion_trigger
    BEFORE INSERT OR UPDATE ON public.dish_cooking_batches
    FOR EACH ROW EXECUTE FUNCTION update_order_items_on_batch_completion();

-- Also create an AFTER trigger to handle cases where BEFORE doesn't work
CREATE OR REPLACE FUNCTION update_order_items_after_batch_change()
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
        AND oi.cooking_status = 'pending';
        
        RAISE NOTICE 'Updated % order items to cooking status for dish % on date %', 
            (SELECT COUNT(*) FROM public.order_items oi 
             JOIN public.orders o ON oi.order_id = o.id 
             WHERE oi.dish_id = NEW.dish_id 
             AND o.delivery_date = NEW.batch_date 
             AND oi.cooking_status = 'cooking'), 
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
        AND oi.cooking_status != 'cooked';
        
        RAISE NOTICE 'Updated % order items to cooked status for dish % on date %', 
            (SELECT COUNT(*) FROM public.order_items oi 
             JOIN public.orders o ON oi.order_id = o.id 
             WHERE oi.dish_id = NEW.dish_id 
             AND o.delivery_date = NEW.batch_date 
             AND oi.cooking_status = 'cooked'), 
            NEW.dish_id, NEW.batch_date;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_order_items_after_batch_change_trigger
    AFTER INSERT OR UPDATE ON public.dish_cooking_batches
    FOR EACH ROW EXECUTE FUNCTION update_order_items_after_batch_change();
