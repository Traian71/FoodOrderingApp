-- Fix admin functions to match actual schema
-- This migration drops and recreates functions with correct column references

-- Drop triggers first (they depend on functions)
DROP TRIGGER IF EXISTS update_order_items_on_batch_completion_trigger ON public.dish_cooking_batches;

-- Drop existing functions that reference non-existent columns
DROP FUNCTION IF EXISTS get_admin_orders_with_cooking_status(TEXT, DATE, DATE);
DROP FUNCTION IF EXISTS get_weekly_dish_summary(DATE, DATE);
DROP FUNCTION IF EXISTS start_dish_cooking_batch(UUID, DATE);
DROP FUNCTION IF EXISTS complete_dish_cooking_batch(UUID, DATE);
DROP FUNCTION IF EXISTS update_order_items_on_batch_completion();

-- Drop the dish_cooking_batches table since we need to rebuild the schema properly
DROP TABLE IF EXISTS public.dish_cooking_batches;

-- Now add the missing columns to order_items table first
ALTER TABLE public.order_items 
ADD COLUMN IF NOT EXISTS cooking_status TEXT DEFAULT 'pending' CHECK (cooking_status IN ('pending', 'cooking', 'cooked')),
ADD COLUMN IF NOT EXISTS cooking_started_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS cooking_completed_at TIMESTAMP WITH TIME ZONE;

-- Recreate dish cooking batches table
CREATE TABLE public.dish_cooking_batches (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    dish_id UUID REFERENCES public.dishes(id) ON DELETE CASCADE NOT NULL,
    batch_date DATE DEFAULT CURRENT_DATE NOT NULL,
    total_quantity INTEGER NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'cooking', 'completed')),
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT dish_cooking_batches_quantity_check CHECK (total_quantity > 0),
    UNIQUE(dish_id, batch_date)
);

-- Add updated_at trigger for dish_cooking_batches
CREATE TRIGGER update_dish_cooking_batches_updated_at 
    BEFORE UPDATE ON public.dish_cooking_batches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Recreate the trigger function for batch completion
CREATE OR REPLACE FUNCTION update_order_items_on_batch_completion()
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

-- Recreate the trigger
CREATE TRIGGER update_order_items_on_batch_completion_trigger
    BEFORE UPDATE ON public.dish_cooking_batches
    FOR EACH ROW EXECUTE FUNCTION update_order_items_on_batch_completion();

-- Recreate get_weekly_dish_summary function
CREATE OR REPLACE FUNCTION get_weekly_dish_summary(
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

-- Recreate get_admin_orders_with_cooking_status function with correct schema
CREATE OR REPLACE FUNCTION get_admin_orders_with_cooking_status(
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

-- Recreate start_dish_cooking_batch function
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
    SELECT SUM(oi.quantity) INTO total_qty
    FROM public.order_items oi
    JOIN public.orders o ON oi.order_id = o.id
    WHERE oi.dish_id = p_dish_id
    AND o.delivery_date = p_batch_date
    AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery');
    
    -- Create or update cooking batch
    INSERT INTO public.dish_cooking_batches (dish_id, batch_date, total_quantity, status)
    VALUES (p_dish_id, p_batch_date, COALESCE(total_qty, 0), 'cooking')
    ON CONFLICT (dish_id, batch_date) 
    DO UPDATE SET 
        status = 'cooking',
        total_quantity = COALESCE(total_qty, 0),
        updated_at = NOW()
    RETURNING id INTO batch_id;
    
    RETURN batch_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate complete_dish_cooking_batch function
CREATE OR REPLACE FUNCTION complete_dish_cooking_batch(
    p_dish_id UUID,
    p_batch_date DATE DEFAULT CURRENT_DATE
)
RETURNS BOOLEAN AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    -- Update cooking batch to completed
    UPDATE public.dish_cooking_batches
    SET status = 'completed', updated_at = NOW()
    WHERE dish_id = p_dish_id AND batch_date = p_batch_date;
    
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    -- If no batch exists, create one and mark as completed
    IF rows_affected = 0 THEN
        INSERT INTO public.dish_cooking_batches (dish_id, batch_date, total_quantity, status)
        SELECT 
            p_dish_id,
            p_batch_date,
            COALESCE(SUM(oi.quantity), 0),
            'completed'
        FROM public.order_items oi
        JOIN public.orders o ON oi.order_id = o.id
        WHERE oi.dish_id = p_dish_id
        AND o.delivery_date = p_batch_date
        AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery');
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions for admin functions
GRANT EXECUTE ON FUNCTION get_weekly_dish_summary(DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_orders_with_cooking_status(TEXT, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION start_dish_cooking_batch(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION complete_dish_cooking_batch(UUID, DATE) TO authenticated;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_order_items_cooking_status ON public.order_items(cooking_status);
CREATE INDEX IF NOT EXISTS idx_order_items_dish_cooking ON public.order_items(dish_id, cooking_status);
CREATE INDEX IF NOT EXISTS idx_dish_cooking_batches_date ON public.dish_cooking_batches(batch_date);
CREATE INDEX IF NOT EXISTS idx_dish_cooking_batches_status ON public.dish_cooking_batches(status);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_date_status ON public.orders(delivery_date, status);
