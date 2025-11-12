-- Fix RLS policies for user_carts and cart_items
-- These tables were missing INSERT, UPDATE, and DELETE policies
-- which caused cart operations to fail silently

-- Enable RLS on cart tables if not already enabled
ALTER TABLE public.user_carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to recreate them properly
DROP POLICY IF EXISTS "Users can view their own carts" ON public.user_carts;
DROP POLICY IF EXISTS "Users can view their own cart items" ON public.cart_items;

-- User Carts Policies
-- Allow users to view their own carts
CREATE POLICY "Users can view their own carts"
    ON public.user_carts FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Allow users to create their own carts
CREATE POLICY "Users can create their own carts"
    ON public.user_carts FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- Allow users to update their own carts
CREATE POLICY "Users can update their own carts"
    ON public.user_carts FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Allow users to delete their own carts
CREATE POLICY "Users can delete their own carts"
    ON public.user_carts FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- Service role gets full access
CREATE POLICY "Service role full access to user_carts"
    ON public.user_carts FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Cart Items Policies
-- Allow users to view their own cart items
CREATE POLICY "Users can view their own cart items"
    ON public.cart_items FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_carts
            WHERE user_carts.id = cart_items.cart_id
            AND user_carts.user_id = auth.uid()
        )
    );

-- Allow users to add items to their own carts
CREATE POLICY "Users can add items to their own carts"
    ON public.cart_items FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_carts
            WHERE user_carts.id = cart_items.cart_id
            AND user_carts.user_id = auth.uid()
        )
    );

-- Allow users to update items in their own carts
CREATE POLICY "Users can update items in their own carts"
    ON public.cart_items FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_carts
            WHERE user_carts.id = cart_items.cart_id
            AND user_carts.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_carts
            WHERE user_carts.id = cart_items.cart_id
            AND user_carts.user_id = auth.uid()
        )
    );

-- Allow users to delete items from their own carts
CREATE POLICY "Users can delete items from their own carts"
    ON public.cart_items FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_carts
            WHERE user_carts.id = cart_items.cart_id
            AND user_carts.user_id = auth.uid()
        )
    );

-- Service role gets full access
CREATE POLICY "Service role full access to cart_items"
    ON public.cart_items FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Grant necessary table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_carts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cart_items TO authenticated;
GRANT ALL ON public.user_carts TO service_role;
GRANT ALL ON public.cart_items TO service_role;
