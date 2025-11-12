-- Fix user signup RLS issue
-- Ensures authenticated users can create their own profile during signup

-- First, ensure service_role has full access (critical for triggers and backend operations)
DROP POLICY IF EXISTS "service_role_full_access" ON public.users;
CREATE POLICY "service_role_full_access" ON public.users
    FOR ALL TO service_role 
    USING (true) 
    WITH CHECK (true);

-- Drop existing user policies to recreate them with correct configuration
DROP POLICY IF EXISTS "users_insert_own" ON public.users;
DROP POLICY IF EXISTS "users_select_own" ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;

-- Allow authenticated users to INSERT their own profile during signup
-- This is the critical policy that was missing or misconfigured
CREATE POLICY "users_insert_own" ON public.users
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = id);

-- Allow authenticated users to SELECT their own profile
CREATE POLICY "users_select_own" ON public.users
    FOR SELECT TO authenticated
    USING (auth.uid() = id);

-- Allow authenticated users to UPDATE their own profile
CREATE POLICY "users_update_own" ON public.users
    FOR UPDATE TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Admin policies should already exist from previous migrations
-- (admin_users_can_view_all_users and admin_users_can_update_users)
