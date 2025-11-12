-- Fix RLS policies for protein options and related tables
-- This migration ensures proper access to the new protein options structure

-- First, ensure anon users can read protein options (needed for public menu access)
DROP POLICY IF EXISTS "Allow anon read access to protein options" ON public.protein_options;
CREATE POLICY "Allow anon read access to protein options"
    ON public.protein_options FOR SELECT
    TO anon
    USING (is_active = true);

DROP POLICY IF EXISTS "Allow anon read access to dish protein options" ON public.dish_protein_options;
CREATE POLICY "Allow anon read access to dish protein options"
    ON public.dish_protein_options FOR SELECT
    TO anon
    USING (true);

-- Ensure authenticated users can read their own carts with protein options
-- The existing cart policies should work, but let's make sure the join works
DROP POLICY IF EXISTS "Users can view their own carts" ON public.user_carts;
CREATE POLICY "Users can view their own carts"
    ON public.user_carts FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can view their own cart items" ON public.cart_items;
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

-- Ensure dishes can be read by authenticated and anon users
DROP POLICY IF EXISTS "Allow read access to active dishes" ON public.dishes;
CREATE POLICY "Allow read access to active dishes"
    ON public.dishes FOR SELECT
    TO authenticated, anon
    USING (is_active = true);

-- Ensure token wallets can be read by their owners
DROP POLICY IF EXISTS "Users can view their own token wallet" ON public.token_wallets;
CREATE POLICY "Users can view their own token wallet"
    ON public.token_wallets FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Grant necessary permissions to anon role for public access
GRANT SELECT ON public.protein_options TO anon;
GRANT SELECT ON public.dish_protein_options TO anon;
GRANT SELECT ON public.dishes TO anon;
GRANT SELECT ON public.menu_items TO anon;
GRANT SELECT ON public.menu_months TO anon;

-- Grant permissions to authenticated users
GRANT SELECT ON public.protein_options TO authenticated;
GRANT SELECT ON public.dish_protein_options TO authenticated;
GRANT SELECT ON public.user_carts TO authenticated;
GRANT SELECT ON public.cart_items TO authenticated;
GRANT SELECT ON public.token_wallets TO authenticated;
