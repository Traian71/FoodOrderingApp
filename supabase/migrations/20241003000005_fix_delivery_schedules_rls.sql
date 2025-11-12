-- Add delivery_group to users table and fix RLS policies
-- Migration: 20241003000005_add_delivery_group_to_users.sql

-- ============================================
-- Add delivery_group column to users table
-- ============================================

-- Add delivery_group column to users table
-- This allows users to be assigned to one of 4 delivery zones (1-4)
ALTER TABLE public.users 
ADD COLUMN delivery_group delivery_group;

-- Add index for faster lookups
CREATE INDEX idx_users_delivery_group ON public.users(delivery_group);

-- Note: Existing users will have NULL delivery_group until manually assigned
-- You can update existing users with:
-- UPDATE public.users SET delivery_group = '1' WHERE id = 'user-id-here';

-- ============================================
-- Fix delivery_schedules RLS policies
-- ============================================

-- Drop the blocking policy for authenticated users
DROP POLICY IF EXISTS "block_non_service_access" ON public.delivery_schedules;

-- Create a policy that allows authenticated users to view delivery schedules for their own delivery group
CREATE POLICY "users_view_own_group_schedules" ON public.delivery_schedules
    FOR SELECT TO authenticated
    USING (
        delivery_group = (
            SELECT delivery_group 
            FROM public.users 
            WHERE id = auth.uid()
        )
    );

-- Keep service_role full access for admin operations
-- (This policy already exists, no need to recreate)

-- Add policy for anon users to view schedules (for guest checkout flow)
CREATE POLICY "anon_view_all_schedules" ON public.delivery_schedules
    FOR SELECT TO anon
    USING (true);

-- Note: INSERT, UPDATE, DELETE remain restricted to service_role only
-- Regular users and anon can only SELECT (read) delivery schedules

-- ============================================
-- Fix admin_users RLS policies
-- ============================================

-- The existing policy "admin_users_own_record" only allows users to see their own record
-- This is correct, but we need to ensure the query doesn't fail with 406
-- The issue is that regular users (not in admin_users) get blocked

-- Drop and recreate the policy to be more explicit
DROP POLICY IF EXISTS "admin_users_own_record" ON public.admin_users;

-- Allow authenticated users to check if they exist in admin_users
-- This returns empty result for non-admins (which is correct) instead of 406 error
CREATE POLICY "authenticated_check_admin_status" ON public.admin_users
    FOR SELECT TO authenticated
    USING (id = auth.uid());

-- Keep the existing service_role policy for full access
-- (Already exists, no need to recreate)
