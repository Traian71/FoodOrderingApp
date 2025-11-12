-- Migration: Add admin access policies for user management
-- This ADDS policies for admins WITHOUT removing existing user protections
-- Admins can view/update users and related tables, regular users remain blocked

-- ============================================
-- USERS TABLE - Admin Access
-- ============================================

-- Allow admins to view all users
CREATE POLICY "admin_users_can_view_all_users" ON public.users
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.id = auth.uid()
            AND admin_users.is_active = true
        )
    );

-- Allow admins to update users (for group assignment, etc.)
CREATE POLICY "admin_users_can_update_users" ON public.users
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.id = auth.uid()
            AND admin_users.is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.id = auth.uid()
            AND admin_users.is_active = true
        )
    );

-- ============================================
-- USER ADDRESSES - Admin Access
-- ============================================

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
-- USER SUBSCRIPTIONS - Admin Access
-- ============================================

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
-- SUBSCRIPTION PLANS - Admin Access
-- ============================================

-- Allow admins to view all subscription plans (needed for joins)
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
-- TOKEN WALLETS - Admin Access
-- ============================================

-- Allow admins to view all token wallets
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

-- ============================================
-- NOTES
-- ============================================
-- This migration ADDS admin policies on top of existing RLS policies
-- The "block_non_service_access" policies remain in place for regular users
-- Only users in the admin_users table can access this data
-- service_role still has full access via existing policies
-- Regular authenticated users remain blocked from accessing other users' data
