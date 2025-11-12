-- Migration: Add orders cap per delivery group
-- This migration implements a weekly order cap system where admins can limit
-- the total number of dishes that can be ordered per ordering window per group.
-- The cap resets when each group's ordering window opens.

-- Step 1: Add order cap columns to menu_months table
-- We need both the initial cap (set by admin) and current remaining cap per group
ALTER TABLE public.menu_months
ADD COLUMN orders_cap_group1_initial INTEGER,
ADD COLUMN orders_cap_group1_remaining INTEGER,
ADD COLUMN orders_cap_group2_initial INTEGER,
ADD COLUMN orders_cap_group2_remaining INTEGER,
ADD COLUMN orders_cap_group3_initial INTEGER,
ADD COLUMN orders_cap_group3_remaining INTEGER,
ADD COLUMN orders_cap_group4_initial INTEGER,
ADD COLUMN orders_cap_group4_remaining INTEGER;

-- Add constraints to ensure caps are valid
ALTER TABLE public.menu_months
ADD CONSTRAINT menu_months_group1_cap_check 
  CHECK (orders_cap_group1_initial IS NULL OR orders_cap_group1_initial >= 0),
ADD CONSTRAINT menu_months_group1_remaining_check 
  CHECK (orders_cap_group1_remaining IS NULL OR orders_cap_group1_remaining >= 0),
ADD CONSTRAINT menu_months_group2_cap_check 
  CHECK (orders_cap_group2_initial IS NULL OR orders_cap_group2_initial >= 0),
ADD CONSTRAINT menu_months_group2_remaining_check 
  CHECK (orders_cap_group2_remaining IS NULL OR orders_cap_group2_remaining >= 0),
ADD CONSTRAINT menu_months_group3_cap_check 
  CHECK (orders_cap_group3_initial IS NULL OR orders_cap_group3_initial >= 0),
ADD CONSTRAINT menu_months_group3_remaining_check 
  CHECK (orders_cap_group3_remaining IS NULL OR orders_cap_group3_remaining >= 0),
ADD CONSTRAINT menu_months_group4_cap_check 
  CHECK (orders_cap_group4_initial IS NULL OR orders_cap_group4_initial >= 0),
ADD CONSTRAINT menu_months_group4_remaining_check 
  CHECK (orders_cap_group4_remaining IS NULL OR orders_cap_group4_remaining >= 0);

-- Step 2: Create function to reset order cap for a specific group
-- This should be called when a group's ordering window opens
CREATE OR REPLACE FUNCTION public.reset_order_cap_for_group(
    p_menu_month_id UUID,
    p_delivery_group delivery_group
)
RETURNS VOID AS $$
BEGIN
    CASE p_delivery_group
        WHEN '1' THEN
            UPDATE public.menu_months
            SET orders_cap_group1_remaining = orders_cap_group1_initial
            WHERE id = p_menu_month_id
              AND orders_cap_group1_initial IS NOT NULL;
        WHEN '2' THEN
            UPDATE public.menu_months
            SET orders_cap_group2_remaining = orders_cap_group2_initial
            WHERE id = p_menu_month_id
              AND orders_cap_group2_initial IS NOT NULL;
        WHEN '3' THEN
            UPDATE public.menu_months
            SET orders_cap_group3_remaining = orders_cap_group3_initial
            WHERE id = p_menu_month_id
              AND orders_cap_group3_initial IS NOT NULL;
        WHEN '4' THEN
            UPDATE public.menu_months
            SET orders_cap_group4_remaining = orders_cap_group4_initial
            WHERE id = p_menu_month_id
              AND orders_cap_group4_initial IS NOT NULL;
    END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Create function to check if order cap allows ordering
CREATE OR REPLACE FUNCTION public.check_order_cap_available(
    p_menu_month_id UUID,
    p_delivery_group delivery_group,
    p_total_dishes INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
    v_remaining_cap INTEGER;
BEGIN
    -- Get remaining cap for the delivery group
    CASE p_delivery_group
        WHEN '1' THEN
            SELECT orders_cap_group1_remaining INTO v_remaining_cap
            FROM public.menu_months
            WHERE id = p_menu_month_id;
        WHEN '2' THEN
            SELECT orders_cap_group2_remaining INTO v_remaining_cap
            FROM public.menu_months
            WHERE id = p_menu_month_id;
        WHEN '3' THEN
            SELECT orders_cap_group3_remaining INTO v_remaining_cap
            FROM public.menu_months
            WHERE id = p_menu_month_id;
        WHEN '4' THEN
            SELECT orders_cap_group4_remaining INTO v_remaining_cap
            FROM public.menu_months
            WHERE id = p_menu_month_id;
    END CASE;
    
    -- If no cap is set (NULL), allow ordering
    IF v_remaining_cap IS NULL THEN
        RETURN true;
    END IF;
    
    -- Check if there's enough capacity
    RETURN v_remaining_cap >= p_total_dishes;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Create function to deduct from order cap
CREATE OR REPLACE FUNCTION public.deduct_from_order_cap(
    p_menu_month_id UUID,
    p_delivery_group delivery_group,
    p_total_dishes INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
    v_remaining_cap INTEGER;
    v_rows_updated INTEGER;
BEGIN
    -- First check if cap allows this order
    IF NOT public.check_order_cap_available(p_menu_month_id, p_delivery_group, p_total_dishes) THEN
        RETURN false;
    END IF;
    
    -- Deduct from the appropriate group's remaining cap
    CASE p_delivery_group
        WHEN '1' THEN
            UPDATE public.menu_months
            SET orders_cap_group1_remaining = GREATEST(0, orders_cap_group1_remaining - p_total_dishes)
            WHERE id = p_menu_month_id
              AND orders_cap_group1_remaining IS NOT NULL
              AND orders_cap_group1_remaining >= p_total_dishes;
            GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
        WHEN '2' THEN
            UPDATE public.menu_months
            SET orders_cap_group2_remaining = GREATEST(0, orders_cap_group2_remaining - p_total_dishes)
            WHERE id = p_menu_month_id
              AND orders_cap_group2_remaining IS NOT NULL
              AND orders_cap_group2_remaining >= p_total_dishes;
            GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
        WHEN '3' THEN
            UPDATE public.menu_months
            SET orders_cap_group3_remaining = GREATEST(0, orders_cap_group3_remaining - p_total_dishes)
            WHERE id = p_menu_month_id
              AND orders_cap_group3_remaining IS NOT NULL
              AND orders_cap_group3_remaining >= p_total_dishes;
            GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
        WHEN '4' THEN
            UPDATE public.menu_months
            SET orders_cap_group4_remaining = GREATEST(0, orders_cap_group4_remaining - p_total_dishes)
            WHERE id = p_menu_month_id
              AND orders_cap_group4_remaining IS NOT NULL
              AND orders_cap_group4_remaining >= p_total_dishes;
            GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    END CASE;
    
    -- If no cap is set, return true (no cap to deduct from)
    IF v_rows_updated = 0 THEN
        -- Check if it's because there's no cap set
        CASE p_delivery_group
            WHEN '1' THEN
                SELECT orders_cap_group1_remaining INTO v_remaining_cap
                FROM public.menu_months WHERE id = p_menu_month_id;
            WHEN '2' THEN
                SELECT orders_cap_group2_remaining INTO v_remaining_cap
                FROM public.menu_months WHERE id = p_menu_month_id;
            WHEN '3' THEN
                SELECT orders_cap_group3_remaining INTO v_remaining_cap
                FROM public.menu_months WHERE id = p_menu_month_id;
            WHEN '4' THEN
                SELECT orders_cap_group4_remaining INTO v_remaining_cap
                FROM public.menu_months WHERE id = p_menu_month_id;
        END CASE;
        
        -- If cap is NULL, it means no cap is set, so allow the order
        RETURN v_remaining_cap IS NULL;
    END IF;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Create trigger function to automatically deduct from cap when order is created
CREATE OR REPLACE FUNCTION public.deduct_order_cap_on_order_creation()
RETURNS TRIGGER AS $$
BEGIN
    -- Deduct from cap immediately when order is created, regardless of status
    IF NOT public.deduct_from_order_cap(
        NEW.menu_month_id,
        NEW.delivery_group,
        NEW.total_meals
    ) THEN
        RAISE EXCEPTION 'Order cap exceeded for delivery group %. Please try ordering fewer dishes.', NEW.delivery_group;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for regular orders
DROP TRIGGER IF EXISTS trigger_deduct_order_cap ON public.orders;
CREATE TRIGGER trigger_deduct_order_cap
    BEFORE INSERT ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.deduct_order_cap_on_order_creation();

-- Step 6: Create trigger function for guest orders
CREATE OR REPLACE FUNCTION public.deduct_order_cap_on_guest_order_creation()
RETURNS TRIGGER AS $$
BEGIN
    -- Deduct from cap immediately when order is created, regardless of status
    IF NOT public.deduct_from_order_cap(
        NEW.menu_month_id,
        NEW.delivery_group,
        NEW.total_meals
    ) THEN
        RAISE EXCEPTION 'Order cap exceeded for delivery group %. Please try ordering fewer dishes.', NEW.delivery_group;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for guest orders
DROP TRIGGER IF EXISTS trigger_deduct_order_cap_guest ON public.guest_orders;
CREATE TRIGGER trigger_deduct_order_cap_guest
    BEFORE INSERT ON public.guest_orders
    FOR EACH ROW
    EXECUTE FUNCTION public.deduct_order_cap_on_guest_order_creation();

-- Step 7: Create function to restore cap when order is cancelled or deleted
CREATE OR REPLACE FUNCTION public.restore_order_cap_on_cancellation()
RETURNS TRIGGER AS $$
BEGIN
    -- If order is being cancelled, restore the cap
    IF OLD.status != 'cancelled' AND NEW.status = 'cancelled' THEN
        CASE NEW.delivery_group
            WHEN '1' THEN
                UPDATE public.menu_months
                SET orders_cap_group1_remaining = orders_cap_group1_remaining + OLD.total_meals
                WHERE id = NEW.menu_month_id
                  AND orders_cap_group1_remaining IS NOT NULL;
            WHEN '2' THEN
                UPDATE public.menu_months
                SET orders_cap_group2_remaining = orders_cap_group2_remaining + OLD.total_meals
                WHERE id = NEW.menu_month_id
                  AND orders_cap_group2_remaining IS NOT NULL;
            WHEN '3' THEN
                UPDATE public.menu_months
                SET orders_cap_group3_remaining = orders_cap_group3_remaining + OLD.total_meals
                WHERE id = NEW.menu_month_id
                  AND orders_cap_group3_remaining IS NOT NULL;
            WHEN '4' THEN
                UPDATE public.menu_months
                SET orders_cap_group4_remaining = orders_cap_group4_remaining + OLD.total_meals
                WHERE id = NEW.menu_month_id
                  AND orders_cap_group4_remaining IS NOT NULL;
        END CASE;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for order cancellations
DROP TRIGGER IF EXISTS trigger_restore_order_cap ON public.orders;
CREATE TRIGGER trigger_restore_order_cap
    AFTER UPDATE ON public.orders
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.restore_order_cap_on_cancellation();

-- Create trigger for guest order cancellations
DROP TRIGGER IF EXISTS trigger_restore_order_cap_guest ON public.guest_orders;
CREATE TRIGGER trigger_restore_order_cap_guest
    AFTER UPDATE ON public.guest_orders
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.restore_order_cap_on_cancellation();

-- Step 8: Create function to get remaining order cap for a delivery group
CREATE OR REPLACE FUNCTION public.get_remaining_order_cap(
    p_menu_month_id UUID,
    p_delivery_group delivery_group
)
RETURNS TABLE (
    initial_cap INTEGER,
    remaining_cap INTEGER,
    cap_enabled BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        CASE p_delivery_group
            WHEN '1' THEN mm.orders_cap_group1_initial
            WHEN '2' THEN mm.orders_cap_group2_initial
            WHEN '3' THEN mm.orders_cap_group3_initial
            WHEN '4' THEN mm.orders_cap_group4_initial
        END as initial_cap,
        CASE p_delivery_group
            WHEN '1' THEN mm.orders_cap_group1_remaining
            WHEN '2' THEN mm.orders_cap_group2_remaining
            WHEN '3' THEN mm.orders_cap_group3_remaining
            WHEN '4' THEN mm.orders_cap_group4_remaining
        END as remaining_cap,
        CASE p_delivery_group
            WHEN '1' THEN mm.orders_cap_group1_initial IS NOT NULL
            WHEN '2' THEN mm.orders_cap_group2_initial IS NOT NULL
            WHEN '3' THEN mm.orders_cap_group3_initial IS NOT NULL
            WHEN '4' THEN mm.orders_cap_group4_initial IS NOT NULL
        END as cap_enabled
    FROM public.menu_months mm
    WHERE mm.id = p_menu_month_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 9: Create admin function to set order cap for a group
CREATE OR REPLACE FUNCTION public.admin_set_order_cap(
    p_menu_month_id UUID,
    p_delivery_group delivery_group,
    p_cap_value INTEGER
)
RETURNS VOID AS $$
BEGIN
    -- Validate cap value
    IF p_cap_value < 0 THEN
        RAISE EXCEPTION 'Order cap must be a positive number or zero';
    END IF;
    
    -- Set both initial and remaining cap
    CASE p_delivery_group
        WHEN '1' THEN
            UPDATE public.menu_months
            SET orders_cap_group1_initial = p_cap_value,
                orders_cap_group1_remaining = p_cap_value
            WHERE id = p_menu_month_id;
        WHEN '2' THEN
            UPDATE public.menu_months
            SET orders_cap_group2_initial = p_cap_value,
                orders_cap_group2_remaining = p_cap_value
            WHERE id = p_menu_month_id;
        WHEN '3' THEN
            UPDATE public.menu_months
            SET orders_cap_group3_initial = p_cap_value,
                orders_cap_group3_remaining = p_cap_value
            WHERE id = p_menu_month_id;
        WHEN '4' THEN
            UPDATE public.menu_months
            SET orders_cap_group4_initial = p_cap_value,
                orders_cap_group4_remaining = p_cap_value
            WHERE id = p_menu_month_id;
    END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 10: Grant execute permissions
GRANT EXECUTE ON FUNCTION public.reset_order_cap_for_group(UUID, delivery_group) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_order_cap_available(UUID, delivery_group, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_remaining_order_cap(UUID, delivery_group) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_order_cap(UUID, delivery_group, INTEGER) TO authenticated;

-- Step 11: Add helpful comments
COMMENT ON COLUMN public.menu_months.orders_cap_group1_initial IS 'Maximum number of dishes that can be ordered during group 1 ordering window. Set by admin when creating menu. NULL means no cap.';
COMMENT ON COLUMN public.menu_months.orders_cap_group1_remaining IS 'Current remaining capacity for group 1. Decreases with each order, resets when ordering window opens.';
COMMENT ON COLUMN public.menu_months.orders_cap_group2_initial IS 'Maximum number of dishes that can be ordered during group 2 ordering window. Set by admin when creating menu. NULL means no cap.';
COMMENT ON COLUMN public.menu_months.orders_cap_group2_remaining IS 'Current remaining capacity for group 2. Decreases with each order, resets when ordering window opens.';
COMMENT ON COLUMN public.menu_months.orders_cap_group3_initial IS 'Maximum number of dishes that can be ordered during group 3 ordering window. Set by admin when creating menu. NULL means no cap.';
COMMENT ON COLUMN public.menu_months.orders_cap_group3_remaining IS 'Current remaining capacity for group 3. Decreases with each order, resets when ordering window opens.';
COMMENT ON COLUMN public.menu_months.orders_cap_group4_initial IS 'Maximum number of dishes that can be ordered during group 4 ordering window. Set by admin when creating menu. NULL means no cap.';
COMMENT ON COLUMN public.menu_months.orders_cap_group4_remaining IS 'Current remaining capacity for group 4. Decreases with each order, resets when ordering window opens.';

COMMENT ON FUNCTION public.reset_order_cap_for_group(UUID, delivery_group) IS 'Resets the remaining order cap to the initial value for a specific delivery group. Should be called when the ordering window opens.';
COMMENT ON FUNCTION public.check_order_cap_available(UUID, delivery_group, INTEGER) IS 'Checks if there is enough remaining capacity for an order of the specified size.';
COMMENT ON FUNCTION public.get_remaining_order_cap(UUID, delivery_group) IS 'Returns the initial cap, remaining cap, and whether cap is enabled for a delivery group.';
COMMENT ON FUNCTION public.admin_set_order_cap(UUID, delivery_group, INTEGER) IS 'Admin function to set the order cap for a specific delivery group. Sets both initial and remaining values.';
