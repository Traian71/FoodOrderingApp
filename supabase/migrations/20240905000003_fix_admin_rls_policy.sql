-- Fix admin_users RLS policy to allow self-lookup
-- The current policy creates a circular dependency where users need to be admin to check if they're admin

-- Drop the existing restrictive policy
DROP POLICY IF EXISTS "admin_users_select_policy" ON public.admin_users;

-- Create a new policy that allows users to check their own admin status
CREATE POLICY "admin_users_self_select_policy" ON public.admin_users
    FOR SELECT USING (
        -- Allow users to see their own admin record
        id = auth.uid()
        OR
        -- Allow existing admins to see all admin records
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.id = auth.uid() AND au.is_active = true
        )
    );

-- Also create a policy to allow service_role full access (for backend operations)
CREATE POLICY "admin_users_service_role_policy" ON public.admin_users
    FOR ALL TO service_role USING (true) WITH CHECK (true);
