-- Migration: Add batch-to-order assignment tracking for food safety and recalls
-- This creates a link between production batches and specific order items
-- Critical for: food recalls, contamination tracking, production statistics

-- Create batch fulfillment tracking table
CREATE TABLE public.batch_order_fulfillment (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    batch_id UUID REFERENCES public.dish_cooking_batches(id) ON DELETE CASCADE NOT NULL,
    order_item_id UUID REFERENCES public.order_items(id) ON DELETE CASCADE NOT NULL,
    quantity_fulfilled INTEGER NOT NULL,
    fulfilled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT batch_order_fulfillment_quantity_check CHECK (quantity_fulfilled > 0),
    -- Prevent duplicate assignments
    UNIQUE(batch_id, order_item_id)
);

-- Add indexes for performance
CREATE INDEX idx_batch_fulfillment_batch_id ON public.batch_order_fulfillment(batch_id);
CREATE INDEX idx_batch_fulfillment_order_item_id ON public.batch_order_fulfillment(order_item_id);
CREATE INDEX idx_batch_fulfillment_fulfilled_at ON public.batch_order_fulfillment(fulfilled_at);

-- Add batch_id reference to order_items for quick lookup
ALTER TABLE public.order_items 
ADD COLUMN fulfilled_by_batch_id UUID REFERENCES public.dish_cooking_batches(id) ON DELETE SET NULL;

CREATE INDEX idx_order_items_batch_id ON public.order_items(fulfilled_by_batch_id);

-- Update the batch completion trigger to record fulfillment assignments
CREATE OR REPLACE FUNCTION update_order_items_on_batch_completion()
RETURNS TRIGGER AS $$
DECLARE
    affected_order_item RECORD;
BEGIN
    -- When a batch is marked as completed, update all order items for that dish on that date
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        -- Loop through all matching order items and create fulfillment records
        FOR affected_order_item IN
            SELECT oi.id, oi.quantity
            FROM public.order_items oi
            JOIN public.orders o ON oi.order_id = o.id
            WHERE oi.dish_id = NEW.dish_id
            AND o.delivery_date = NEW.batch_date
            AND oi.cooking_status != 'cooked'
            AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery')
        LOOP
            -- Create fulfillment record
            INSERT INTO public.batch_order_fulfillment (batch_id, order_item_id, quantity_fulfilled)
            VALUES (NEW.id, affected_order_item.id, affected_order_item.quantity)
            ON CONFLICT (batch_id, order_item_id) DO NOTHING;
            
            -- Update order item with batch reference
            UPDATE public.order_items
            SET fulfilled_by_batch_id = NEW.id
            WHERE id = affected_order_item.id;
        END LOOP;
        
        -- Update cooking status for all affected order items
        UPDATE public.order_items oi
        SET 
            cooking_status = 'cooked',
            cooking_completed_at = NOW()
        FROM public.orders o
        WHERE oi.order_id = o.id
        AND oi.dish_id = NEW.dish_id
        AND o.delivery_date = NEW.batch_date
        AND oi.cooking_status != 'cooked'
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
        AND o.status IN ('confirmed', 'preparing', 'packed', 'out_for_delivery');
        
        -- Update batch start timestamp
        NEW.started_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to get all orders affected by a specific batch (for recalls)
CREATE OR REPLACE FUNCTION get_orders_by_batch(
    p_batch_id UUID
)
RETURNS TABLE (
    order_id UUID,
    order_number TEXT,
    customer_name TEXT,
    customer_email TEXT,
    customer_phone TEXT,
    delivery_address TEXT,
    delivery_group TEXT,
    dish_name TEXT,
    quantity_received INTEGER,
    fulfilled_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id as order_id,
        'ORD-' || EXTRACT(YEAR FROM o.created_at) || '-' || LPAD(EXTRACT(DOY FROM o.created_at)::TEXT, 3, '0') || '-' || SUBSTRING(o.id::TEXT, 1, 8) as order_number,
        COALESCE(u.first_name || ' ' || u.last_name, 'Guest Customer') as customer_name,
        u.email as customer_email,
        u.phone as customer_phone,
        ua.address_line_1 || ', ' || ua.city || ' ' || ua.postal_code as delivery_address,
        o.delivery_group::TEXT as delivery_group,
        d.name as dish_name,
        bof.quantity_fulfilled as quantity_received,
        bof.fulfilled_at
    FROM public.batch_order_fulfillment bof
    JOIN public.order_items oi ON bof.order_item_id = oi.id
    JOIN public.orders o ON oi.order_id = o.id
    JOIN public.dishes d ON oi.dish_id = d.id
    LEFT JOIN public.users u ON o.user_id = u.id
    LEFT JOIN public.user_addresses ua ON u.id = ua.user_id AND ua.is_primary = true
    WHERE bof.batch_id = p_batch_id
    ORDER BY bof.fulfilled_at DESC, customer_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get batch history for a specific order item
CREATE OR REPLACE FUNCTION get_batch_history_for_order_item(
    p_order_item_id UUID
)
RETURNS TABLE (
    batch_id UUID,
    dish_name TEXT,
    batch_date DATE,
    quantity_fulfilled INTEGER,
    fulfilled_at TIMESTAMP WITH TIME ZONE,
    batch_status TEXT,
    batch_started_at TIMESTAMP WITH TIME ZONE,
    batch_completed_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dcb.id as batch_id,
        d.name as dish_name,
        dcb.batch_date,
        bof.quantity_fulfilled,
        bof.fulfilled_at,
        dcb.status as batch_status,
        dcb.started_at as batch_started_at,
        dcb.completed_at as batch_completed_at
    FROM public.batch_order_fulfillment bof
    JOIN public.dish_cooking_batches dcb ON bof.batch_id = dcb.id
    JOIN public.dishes d ON dcb.dish_id = d.id
    WHERE bof.order_item_id = p_order_item_id
    ORDER BY bof.fulfilled_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get production statistics for a batch
CREATE OR REPLACE FUNCTION get_batch_production_stats(
    p_batch_id UUID
)
RETURNS TABLE (
    batch_id UUID,
    dish_name TEXT,
    batch_date DATE,
    total_orders_fulfilled INTEGER,
    total_portions_fulfilled INTEGER,
    unique_customers INTEGER,
    delivery_groups TEXT[],
    batch_status TEXT,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dcb.id as batch_id,
        d.name as dish_name,
        dcb.batch_date,
        COUNT(DISTINCT o.id)::INTEGER as total_orders_fulfilled,
        SUM(bof.quantity_fulfilled)::INTEGER as total_portions_fulfilled,
        COUNT(DISTINCT o.user_id)::INTEGER as unique_customers,
        ARRAY_AGG(DISTINCT o.delivery_group::TEXT) as delivery_groups,
        dcb.status as batch_status,
        dcb.started_at,
        dcb.completed_at
    FROM public.dish_cooking_batches dcb
    JOIN public.dishes d ON dcb.dish_id = d.id
    LEFT JOIN public.batch_order_fulfillment bof ON dcb.id = bof.batch_id
    LEFT JOIN public.order_items oi ON bof.order_item_id = oi.id
    LEFT JOIN public.orders o ON oi.order_id = o.id
    WHERE dcb.id = p_batch_id
    GROUP BY dcb.id, d.name, dcb.batch_date, dcb.status, dcb.started_at, dcb.completed_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT SELECT ON public.batch_order_fulfillment TO authenticated;
GRANT EXECUTE ON FUNCTION get_orders_by_batch(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_batch_history_for_order_item(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_batch_production_stats(UUID) TO authenticated;

-- Add RLS policies
ALTER TABLE public.batch_order_fulfillment ENABLE ROW LEVEL SECURITY;

-- Admin users can see all fulfillment records
CREATE POLICY "Admin users can view all batch fulfillments"
    ON public.batch_order_fulfillment
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.id = auth.uid()
        )
    );

-- Regular users can see their own order fulfillments
CREATE POLICY "Users can view their own batch fulfillments"
    ON public.batch_order_fulfillment
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.order_items oi
            JOIN public.orders o ON oi.order_id = o.id
            WHERE oi.id = batch_order_fulfillment.order_item_id
            AND o.user_id = auth.uid()
        )
    );

-- Add comments for documentation
COMMENT ON TABLE public.batch_order_fulfillment IS 'Links production batches to specific order items for food safety traceability and recall management';
COMMENT ON FUNCTION get_orders_by_batch IS 'Retrieves all orders fulfilled by a specific batch - critical for food recalls';
COMMENT ON FUNCTION get_batch_history_for_order_item IS 'Shows which batch(es) fulfilled a specific order item';
COMMENT ON FUNCTION get_batch_production_stats IS 'Production statistics and metrics for a specific cooking batch';
