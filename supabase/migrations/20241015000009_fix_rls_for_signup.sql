-- Simple fix: Allow authenticated users to insert their own profile
-- This is the most straightforward solution for signup

-- Ensure the INSERT policy exists and is correct
DROP POLICY IF EXISTS "users_insert_own" ON public.users;

CREATE POLICY "users_insert_own" ON public.users
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = id);

-- Also ensure anon users can't insert (security)
CREATE POLICY "block_anon_insert" ON public.users
    FOR INSERT TO anon
    WITH CHECK (false);

-- Verify service_role still has full access
DROP POLICY IF EXISTS "service_role_full_access" ON public.users;
CREATE POLICY "service_role_full_access" ON public.users
    FOR ALL TO service_role 
    USING (true) 
    WITH CHECK (true);
