-- Migration: Simplify order cap to single cap for all groups
-- This migration removes the per-group cap system and replaces it with a single cap
-- that applies to all groups and resets per ordering window

-- Step 1: Drop all existing order cap triggers and functions
DROP TRIGGER IF EXISTS trigger_deduct_order_cap ON public.orders;
DROP TRIGGER IF EXISTS trigger_deduct_order_cap_guest ON public.guest_orders;
DROP TRIGGER IF EXISTS trigger_restore_order_cap ON public.orders;
DROP TRIGGER IF EXISTS trigger_restore_order_cap_guest ON public.guest_orders;

DROP FUNCTION IF EXISTS public.deduct_order_cap_on_order_creation();
DROP FUNCTION IF EXISTS public.deduct_order_cap_on_guest_order_creation();
DROP FUNCTION IF EXISTS public.restore_order_cap_on_cancellation();
DROP FUNCTION IF EXISTS public.reset_order_cap_for_group(UUID, delivery_group);
DROP FUNCTION IF EXISTS public.check_order_cap_available(UUID, delivery_group, INTEGER);
DROP FUNCTION IF EXISTS public.deduct_from_order_cap(UUID, delivery_group, INTEGER);
DROP FUNCTION IF EXISTS public.get_remaining_order_cap(UUID, delivery_group);
DROP FUNCTION IF EXISTS public.admin_set_order_cap(UUID, delivery_group, INTEGER);

-- Step 2: Remove all per-group cap columns and constraints
ALTER TABLE public.menu_months
DROP CONSTRAINT IF EXISTS menu_months_group1_cap_check,
DROP CONSTRAINT IF EXISTS menu_months_group1_remaining_check,
DROP CONSTRAINT IF EXISTS menu_months_group2_cap_check,
DROP CONSTRAINT IF EXISTS menu_months_group2_remaining_check,
DROP CONSTRAINT IF EXISTS menu_months_group3_cap_check,
DROP CONSTRAINT IF EXISTS menu_months_group3_remaining_check,
DROP CONSTRAINT IF EXISTS menu_months_group4_cap_check,
DROP CONSTRAINT IF EXISTS menu_months_group4_remaining_check;

ALTER TABLE public.menu_months
DROP COLUMN IF EXISTS orders_cap_group1_initial,
DROP COLUMN IF EXISTS orders_cap_group1_remaining,
DROP COLUMN IF EXISTS orders_cap_group2_initial,
DROP COLUMN IF EXISTS orders_cap_group2_remaining,
DROP COLUMN IF EXISTS orders_cap_group3_initial,
DROP COLUMN IF EXISTS orders_cap_group3_remaining,
DROP COLUMN IF EXISTS orders_cap_group4_initial,
DROP COLUMN IF EXISTS orders_cap_group4_remaining;

-- Step 3: Add single cap columns for all groups
ALTER TABLE public.menu_months
ADD COLUMN orders_cap_initial INTEGER,
ADD COLUMN orders_cap_remaining INTEGER;

-- Add constraints
ALTER TABLE public.menu_months
ADD CONSTRAINT menu_months_orders_cap_check 
  CHECK (orders_cap_initial IS NULL OR orders_cap_initial >= 0),
ADD CONSTRAINT menu_months_orders_cap_remaining_check 
  CHECK (orders_cap_remaining IS NULL OR orders_cap_remaining >= 0);

-- Step 4: Create function to reset order cap (for all groups when window opens)
CREATE OR REPLACE FUNCTION public.reset_order_cap(
    p_menu_month_id UUID
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.menu_months
    SET orders_cap_remaining = orders_cap_initial
    WHERE id = p_menu_month_id
      AND orders_cap_initial IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Create function to check if order cap allows ordering
CREATE OR REPLACE FUNCTION public.check_order_cap_available(
    p_menu_month_id UUID,
    p_total_dishes INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
    v_remaining_cap INTEGER;
BEGIN
    -- Get remaining cap
    SELECT orders_cap_remaining INTO v_remaining_cap
    FROM public.menu_months
    WHERE id = p_menu_month_id;
    
    -- If no cap is set (NULL), allow ordering
    IF v_remaining_cap IS NULL THEN
        RETURN true;
    END IF;
    
    -- Check if there's enough capacity
    RETURN v_remaining_cap >= p_total_dishes;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: Create function to deduct from order cap
CREATE OR REPLACE FUNCTION public.deduct_from_order_cap(
    p_menu_month_id UUID,
    p_total_dishes INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
    v_remaining_cap INTEGER;
    v_rows_updated INTEGER;
BEGIN
    -- First check if cap allows this order
    IF NOT public.check_order_cap_available(p_menu_month_id, p_total_dishes) THEN
        RETURN false;
    END IF;
    
    -- Deduct from remaining cap
    UPDATE public.menu_months
    SET orders_cap_remaining = GREATEST(0, orders_cap_remaining - p_total_dishes)
    WHERE id = p_menu_month_id
      AND orders_cap_remaining IS NOT NULL
      AND orders_cap_remaining >= p_total_dishes;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    -- If no cap is set, return true (no cap to deduct from)
    IF v_rows_updated = 0 THEN
        -- Check if it's because there's no cap set
        SELECT orders_cap_remaining INTO v_remaining_cap
        FROM public.menu_months 
        WHERE id = p_menu_month_id;
        
        -- If cap is NULL, it means no cap is set, so allow the order
        RETURN v_remaining_cap IS NULL;
    END IF;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Create trigger function to automatically deduct from cap when order is created
CREATE OR REPLACE FUNCTION public.deduct_order_cap_on_order_creation()
RETURNS TRIGGER AS $$
BEGIN
    -- Deduct from cap immediately when order is created, regardless of status
    IF NOT public.deduct_from_order_cap(
        NEW.menu_month_id,
        NEW.total_meals
    ) THEN
        RAISE EXCEPTION 'Order cap exceeded. Please try ordering fewer dishes.';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for regular orders
CREATE TRIGGER trigger_deduct_order_cap
    BEFORE INSERT ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.deduct_order_cap_on_order_creation();

-- Create trigger for guest orders
CREATE TRIGGER trigger_deduct_order_cap_guest
    BEFORE INSERT ON public.guest_orders
    FOR EACH ROW
    EXECUTE FUNCTION public.deduct_order_cap_on_order_creation();

-- Step 8: Create function to restore cap when order is cancelled
CREATE OR REPLACE FUNCTION public.restore_order_cap_on_cancellation()
RETURNS TRIGGER AS $$
BEGIN
    -- If order is being cancelled, restore the cap
    IF OLD.status != 'cancelled' AND NEW.status = 'cancelled' THEN
        UPDATE public.menu_months
        SET orders_cap_remaining = orders_cap_remaining + OLD.total_meals
        WHERE id = NEW.menu_month_id
          AND orders_cap_remaining IS NOT NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for order cancellations
CREATE TRIGGER trigger_restore_order_cap
    AFTER UPDATE ON public.orders
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.restore_order_cap_on_cancellation();

-- Create trigger for guest order cancellations
CREATE TRIGGER trigger_restore_order_cap_guest
    AFTER UPDATE ON public.guest_orders
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.restore_order_cap_on_cancellation();

-- Step 9: Create function to get remaining order cap
CREATE OR REPLACE FUNCTION public.get_remaining_order_cap(
    p_menu_month_id UUID
)
RETURNS TABLE (
    initial_cap INTEGER,
    remaining_cap INTEGER,
    cap_enabled BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mm.orders_cap_initial as initial_cap,
        mm.orders_cap_remaining as remaining_cap,
        mm.orders_cap_initial IS NOT NULL as cap_enabled
    FROM public.menu_months mm
    WHERE mm.id = p_menu_month_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 10: Create admin function to set order cap
CREATE OR REPLACE FUNCTION public.admin_set_order_cap(
    p_menu_month_id UUID,
    p_cap_value INTEGER
)
RETURNS VOID AS $$
BEGIN
    -- Validate cap value
    IF p_cap_value < 0 THEN
        RAISE EXCEPTION 'Order cap must be a positive number or zero';
    END IF;
    
    -- Set both initial and remaining cap
    UPDATE public.menu_months
    SET orders_cap_initial = p_cap_value,
        orders_cap_remaining = p_cap_value
    WHERE id = p_menu_month_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 11: Grant execute permissions
GRANT EXECUTE ON FUNCTION public.reset_order_cap(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_order_cap_available(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_remaining_order_cap(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_order_cap(UUID, INTEGER) TO authenticated;

-- Step 12: Add helpful comments
COMMENT ON COLUMN public.menu_months.orders_cap_initial IS 'Maximum number of dishes that can be ordered per ordering window for all groups. Set by admin when creating menu. NULL means no cap.';
COMMENT ON COLUMN public.menu_months.orders_cap_remaining IS 'Current remaining capacity for all groups. Decreases with each order, resets when ordering window opens.';

COMMENT ON FUNCTION public.reset_order_cap(UUID) IS 'Resets the remaining order cap to the initial value. Should be called when each ordering window opens.';
COMMENT ON FUNCTION public.check_order_cap_available(UUID, INTEGER) IS 'Checks if there is enough remaining capacity for an order of the specified size.';
COMMENT ON FUNCTION public.get_remaining_order_cap(UUID) IS 'Returns the initial cap, remaining cap, and whether cap is enabled.';
COMMENT ON FUNCTION public.admin_set_order_cap(UUID, INTEGER) IS 'Admin function to set the order cap. Sets both initial and remaining values.';
