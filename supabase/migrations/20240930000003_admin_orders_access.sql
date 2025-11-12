-- Add admin access policies for orders and order_items
-- This migration allows admin users to access and modify orders

-- First, check if admin_users table exists and create admin access function
CREATE OR REPLACE FUNCTION is_admin_user()
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if the current user exists in admin_users table
    RETURN EXISTS (
        SELECT 1 FROM public.admin_users 
        WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION is_admin_user() TO authenticated;

-- Add admin access policy for orders table
CREATE POLICY "admin_full_access_orders" ON public.orders
    FOR ALL TO authenticated 
    USING (is_admin_user()) 
    WITH CHECK (is_admin_user());

-- Add admin access policy for order_items table  
CREATE POLICY "admin_full_access_order_items" ON public.order_items
    FOR ALL TO authenticated 
    USING (is_admin_user()) 
    WITH CHECK (is_admin_user());

-- Add admin access policy for dish_cooking_batches table
CREATE POLICY "admin_full_access_dish_cooking_batches" ON public.dish_cooking_batches
    FOR ALL TO authenticated 
    USING (is_admin_user()) 
    WITH CHECK (is_admin_user());

-- Grant necessary permissions for admin operations
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.orders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.order_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.dish_cooking_batches TO authenticated;

-- Create indexes for better performance on admin queries
CREATE INDEX IF NOT EXISTS idx_orders_status_delivery_date ON public.orders(status, delivery_date);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_dish_id_cooking ON public.order_items(dish_id, cooking_status);
