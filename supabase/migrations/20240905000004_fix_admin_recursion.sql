-- Fix infinite recursion in admin_users RLS policy
-- Remove all existing policies and create a simple one that allows self-lookup

-- Drop all existing admin_users policies
DROP POLICY IF EXISTS "admin_users_self_select_policy" ON public.admin_users;
DROP POLICY IF EXISTS "admin_users_service_role_policy" ON public.admin_users;
DROP POLICY IF EXISTS "admin_users_select_policy" ON public.admin_users;
DROP POLICY IF EXISTS "admin_users_insert_policy" ON public.admin_users;
DROP POLICY IF EXISTS "admin_users_update_policy" ON public.admin_users;
DROP POLICY IF EXISTS "admin_users_delete_policy" ON public.admin_users;

-- Create a simple policy that allows users to see their own record only
-- This avoids any circular dependency
CREATE POLICY "admin_users_own_record" ON public.admin_users
    FOR SELECT USING (id = auth.uid());

-- Allow service_role full access for backend operations
CREATE POLICY "admin_users_service_full_access" ON public.admin_users
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- For admin operations (insert/update/delete), we'll handle permissions in the application layer
-- This keeps the RLS simple and avoids recursion
