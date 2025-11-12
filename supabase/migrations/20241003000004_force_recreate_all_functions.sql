-- Force recreate all functions and views to clear any cached references to available_protein_options
-- This migration completely drops and recreates all functions that might have cached the old column
-- Also fixes any remaining views that reference the old column

-- First, check if there's a view that still references available_protein_options and drop it
DROP VIEW IF EXISTS public.menu_view CASCADE;

-- Drop ALL functions that might reference dishes table
DROP FUNCTION IF EXISTS public.get_weekly_dish_summary(DATE, DATE) CASCADE;
DROP FUNCTION IF EXISTS public.get_admin_orders_with_cooking_status(TEXT, DATE, DATE) CASCADE;
DROP FUNCTION IF EXISTS public.start_dish_cooking_batch(UUID, DATE) CASCADE;
DROP FUNCTION IF EXISTS public.complete_dish_cooking_batch(UUID, DATE) CASCADE;
DROP FUNCTION IF EXISTS public.update_order_items_on_batch_completion() CASCADE;
DROP FUNCTION IF EXISTS public.update_order_items_after_batch_change() CASCADE;
DROP FUNCTION IF EXISTS public.get_menu_dishes(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.validate_cart_item_protein() CASCADE;
DROP FUNCTION IF EXISTS public.get_dish_protein_options(UUID) CASCADE;

-- Also drop any triggers that might be affected
DROP TRIGGER IF EXISTS update_order_items_on_batch_completion_trigger ON public.dish_cooking_batches;
DROP TRIGGER IF EXISTS update_order_items_after_batch_change_trigger ON public.dish_cooking_batches;
DROP TRIGGER IF EXISTS validate_cart_item_protein_trigger ON public.cart_items;
DROP TRIGGER IF EXISTS validate_guest_cart_item_protein_trigger ON public.guest_cart_items;

-- Recreate start_dish_cooking_batch function
CREATE OR REPLACE FUNCTION public.start_dish_cooking_batch(
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

-- Recreate complete_dish_cooking_batch function
CREATE OR REPLACE FUNCTION public.complete_dish_cooking_batch(
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

-- Recreate get_weekly_dish_summary function
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
    total_orders INTEGER,
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
        COUNT(DISTINCT o.id)::INTEGER as total_orders,
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

-- Recreate get_admin_orders_with_cooking_status function
CREATE OR REPLACE FUNCTION public.get_admin_orders_with_cooking_status(
    status_filter TEXT DEFAULT NULL,
    delivery_date_start DATE DEFAULT NULL,
    delivery_date_end DATE DEFAULT NULL
)
RETURNS TABLE (
    order_id UUID,
    order_number TEXT,
    user_id UUID,
    user_name TEXT,
    user_email TEXT,
    delivery_group TEXT,
    order_status TEXT,
    delivery_date DATE,
    total_items INTEGER,
    total_tokens INTEGER,
    special_instructions TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    dish_id UUID,
    dish_name TEXT,
    dish_quantity INTEGER,
    protein_option TEXT,
    cooking_status TEXT,
    cooking_started_at TIMESTAMP WITH TIME ZONE,
    cooking_completed_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id as order_id,
        'ORD-' || EXTRACT(YEAR FROM o.created_at) || '-' || LPAD(EXTRACT(DOY FROM o.created_at)::TEXT, 3, '0') || '-' || SUBSTRING(o.id::TEXT, 1, 8) as order_number,
        o.user_id,
        COALESCE(u.first_name || ' ' || u.last_name, u.email) as user_name,
        u.email as user_email,
        o.delivery_group::TEXT,
        o.status::TEXT as order_status,
        o.delivery_date,
        o.total_meals as total_items,
        o.total_tokens,
        o.special_instructions,
        o.created_at,
        o.confirmed_at,
        oi.dish_id,
        d.name as dish_name,
        oi.quantity as dish_quantity,
        oi.protein_option,
        oi.cooking_status,
        oi.cooking_started_at,
        oi.cooking_completed_at
    FROM public.orders o
    JOIN public.users u ON o.user_id = u.id
    JOIN public.order_items oi ON o.id = oi.order_id
    JOIN public.dishes d ON oi.dish_id = d.id
    WHERE (status_filter IS NULL OR o.status::TEXT = status_filter)
    AND (delivery_date_start IS NULL OR o.delivery_date >= delivery_date_start)
    AND (delivery_date_end IS NULL OR o.delivery_date <= delivery_date_end)
    ORDER BY o.delivery_date DESC, o.created_at DESC, d.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate get_dish_protein_options function
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

-- Recreate get_menu_dishes function
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

-- Recreate validate_cart_item_protein function
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

-- Recreate trigger function for batch completion
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
        AND oi.cooking_status != 'cooked';
        
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
        AND oi.cooking_status = 'pending';
        
        -- Update batch start timestamp
        NEW.started_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate AFTER trigger function
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

-- Recreate all triggers
CREATE TRIGGER update_order_items_on_batch_completion_trigger
    BEFORE INSERT OR UPDATE ON public.dish_cooking_batches
    FOR EACH ROW EXECUTE FUNCTION update_order_items_on_batch_completion();

CREATE TRIGGER update_order_items_after_batch_change_trigger
    AFTER INSERT OR UPDATE ON public.dish_cooking_batches
    FOR EACH ROW EXECUTE FUNCTION update_order_items_after_batch_change();

CREATE TRIGGER validate_cart_item_protein_trigger
    BEFORE INSERT OR UPDATE ON public.cart_items
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_cart_item_protein();

CREATE TRIGGER validate_guest_cart_item_protein_trigger
    BEFORE INSERT OR UPDATE ON public.guest_cart_items
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_cart_item_protein();

-- Recreate menu_view with proper protein options from new tables
CREATE OR REPLACE VIEW public.menu_view AS
SELECT 
    mm.id as menu_month_id,
    mm.month_number,
    mm.year,
    mm.start_date,
    mm.end_date,
    mm.delivery_start_date,
    mm.delivery_end_date,
    mm.order_cutoff_date,
    mm.is_active as menu_is_active,
    d.id as dish_id,
    d.name as dish_name,
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
    mi.display_order
FROM public.menu_months mm
INNER JOIN public.menu_items mi ON mi.menu_month_id = mm.id
INNER JOIN public.dishes d ON d.id = mi.dish_id
WHERE d.is_active = true;

-- Grant access to the view
GRANT SELECT ON public.menu_view TO authenticated;
GRANT SELECT ON public.menu_view TO anon;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_weekly_dish_summary(DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_orders_with_cooking_status(TEXT, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_dish_cooking_batch(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_dish_cooking_batch(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dish_protein_options(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_menu_dishes(UUID, UUID) TO authenticated;
