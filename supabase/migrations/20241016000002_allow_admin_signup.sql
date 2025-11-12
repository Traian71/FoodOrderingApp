-- Allow users to create their own admin_users record during signup
-- This is needed for the admin signup flow

-- Drop existing restrictive policies if they exist
DROP POLICY IF EXISTS "block_admin_users_insert" ON public.admin_users;

-- Allow authenticated users to insert their own admin record
-- This enables the admin signup flow
CREATE POLICY "users_can_create_own_admin_record" ON public.admin_users
    FOR INSERT 
    TO authenticated
    WITH CHECK (id = auth.uid());

-- Allow admins to update their own record (for last_login, etc.)
CREATE POLICY "admins_can_update_own_record" ON public.admin_users
    FOR UPDATE 
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());
