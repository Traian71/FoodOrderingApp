-- Migration: Allow admin users to access the users table
-- This fixes the issue where admin queries return 0 users due to RLS blocking

-- Drop the blocking policy for authenticated users on the users table
DROP POLICY IF EXISTS "block_non_service_access" ON public.users;

-- Create a policy that allows admin users (from admin_users table) to view all users
CREATE POLICY "admin_users_can_view_all_users" ON public.users
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.id = auth.uid()
            AND admin_users.is_active = true
        )
    );

-- Create a policy that allows admin users to update users (for group assignment)
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

-- Keep service_role full access (already exists, but ensuring it's there)
-- This policy should already exist from the original RLS migration

-- Note: Regular users still cannot access other users' data
-- Only admins (in admin_users table) and service_role can access the users table
