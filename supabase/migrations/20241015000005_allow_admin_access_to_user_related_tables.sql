-- Migration: Allow admin users to access user-related tables
-- This allows admins to view addresses, subscriptions, and token wallets for all users

-- ============================================
-- USER ADDRESSES
-- ============================================

-- Drop the blocking policy
DROP POLICY IF EXISTS "block_non_service_access" ON public.user_addresses;

-- Allow admins to view all user addresses
CREATE POLICY "admin_users_can_view_all_addresses" ON public.user_addresses
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.id = auth.uid()
            AND admin_users.is_active = true
        )
    );

-- ============================================
-- USER SUBSCRIPTIONS
-- ============================================

-- Drop the blocking policy
DROP POLICY IF EXISTS "block_non_service_access" ON public.user_subscriptions;

-- Allow admins to view all user subscriptions
CREATE POLICY "admin_users_can_view_all_subscriptions" ON public.user_subscriptions
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.id = auth.uid()
            AND admin_users.is_active = true
        )
    );

-- ============================================
-- SUBSCRIPTION PLANS (needed for joins)
-- ============================================

-- Drop the blocking policy
DROP POLICY IF EXISTS "block_non_service_access" ON public.subscription_plans;

-- Allow admins to view all subscription plans
CREATE POLICY "admin_users_can_view_subscription_plans" ON public.subscription_plans
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.id = auth.uid()
            AND admin_users.is_active = true
        )
    );

-- ============================================
-- TOKEN WALLETS (admin read access)
-- ============================================

-- Add policy for admins to view all token wallets
-- (existing user policies remain for users to view their own)
CREATE POLICY "admin_users_can_view_all_wallets" ON public.token_wallets
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.id = auth.uid()
            AND admin_users.is_active = true
        )
    );

-- Note: service_role policies remain unchanged and provide full access
-- Regular users still cannot access other users' data
