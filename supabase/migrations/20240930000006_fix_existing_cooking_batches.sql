-- Fix existing cooking batches that were created but didn't update order_items
-- This is a one-time fix for data that was created before the trigger was fixed

-- Update all order_items that should be 'cooking' based on existing batches
UPDATE public.order_items oi
SET 
    cooking_status = 'cooking',
    cooking_started_at = COALESCE(oi.cooking_started_at, NOW())
FROM public.orders o, public.dish_cooking_batches dcb
WHERE oi.order_id = o.id
AND oi.dish_id = dcb.dish_id
AND o.delivery_date = dcb.batch_date
AND dcb.status = 'cooking'
AND oi.cooking_status = 'pending';

-- Update all order_items that should be 'cooked' based on existing batches
UPDATE public.order_items oi
SET 
    cooking_status = 'cooked',
    cooking_completed_at = COALESCE(oi.cooking_completed_at, NOW())
FROM public.orders o, public.dish_cooking_batches dcb
WHERE oi.order_id = o.id
AND oi.dish_id = dcb.dish_id
AND o.delivery_date = dcb.batch_date
AND dcb.status = 'completed'
AND oi.cooking_status != 'cooked';

-- Log the results
DO $$
DECLARE
    cooking_count INTEGER;
    cooked_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO cooking_count
    FROM public.order_items oi
    JOIN public.orders o ON oi.order_id = o.id
    JOIN public.dish_cooking_batches dcb ON oi.dish_id = dcb.dish_id AND o.delivery_date = dcb.batch_date
    WHERE dcb.status = 'cooking' AND oi.cooking_status = 'cooking';
    
    SELECT COUNT(*) INTO cooked_count
    FROM public.order_items oi
    JOIN public.orders o ON oi.order_id = o.id
    JOIN public.dish_cooking_batches dcb ON oi.dish_id = dcb.dish_id AND o.delivery_date = dcb.batch_date
    WHERE dcb.status = 'completed' AND oi.cooking_status = 'cooked';
    
    RAISE NOTICE 'Fixed % order items to cooking status', cooking_count;
    RAISE NOTICE 'Fixed % order items to cooked status', cooked_count;
END $$;
