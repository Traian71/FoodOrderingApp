-- CLEANUP AND CONSOLIDATION MIGRATION
-- This replaces migrations 007, 008, 009, 010 with a single clean solution
-- Created: 2024-10-15

-- ============================================
-- PART 1: Clean up duplicate/unused functions
-- ============================================

-- Drop the unused RPC function (from migration 008)
DROP FUNCTION IF EXISTS public.create_user_profile(UUID, TEXT, TEXT, TEXT, TEXT, TEXT);

-- ============================================
-- PART 2: Set up proper RLS policies for users table
-- ============================================

-- Drop all existing user-related policies to start fresh
DROP POLICY IF EXISTS "users_insert_own" ON public.users;
DROP POLICY IF EXISTS "users_select_own" ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;
DROP POLICY IF EXISTS "block_anon_insert" ON public.users;
DROP POLICY IF EXISTS "service_role_full_access" ON public.users;

-- Service role gets full access (critical for triggers and backend operations)
CREATE POLICY "service_role_full_access" ON public.users
    FOR ALL TO service_role 
    USING (true) 
    WITH CHECK (true);

-- Authenticated users can view their own profile
CREATE POLICY "users_select_own" ON public.users
    FOR SELECT TO authenticated
    USING (auth.uid() = id);

-- Authenticated users can update their own profile
CREATE POLICY "users_update_own" ON public.users
    FOR UPDATE TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Block direct INSERT from client (profiles are created via trigger only)
CREATE POLICY "block_direct_insert" ON public.users
    FOR INSERT TO authenticated, anon
    WITH CHECK (false);

-- ============================================
-- PART 3: Auto-create user profile via trigger
-- ============================================

-- Function to automatically create user profile when auth user is created
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_first_name TEXT;
    v_last_name TEXT;
    v_phone TEXT;
    v_delivery_group delivery_group;
BEGIN
    -- Extract metadata with proper null handling
    v_first_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'first_name', '')), '');
    v_last_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'last_name', '')), '');
    v_phone := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'phone', '')), '');
    
    -- Only set delivery_group if it's provided and valid
    IF NEW.raw_user_meta_data->>'delivery_group' IS NOT NULL 
       AND NEW.raw_user_meta_data->>'delivery_group' IN ('1', '2', '3', '4') THEN
        v_delivery_group := (NEW.raw_user_meta_data->>'delivery_group')::delivery_group;
    ELSE
        v_delivery_group := NULL;
    END IF;
    
    -- Insert into public.users table
    -- This runs with elevated privileges and bypasses RLS
    INSERT INTO public.users (
        id,
        email,
        first_name,
        last_name,
        phone,
        delivery_group,
        group_assigned,
        is_active
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(v_first_name, 'Unknown'),  -- Fallback to 'Unknown' if empty
        COALESCE(v_last_name, 'User'),      -- Fallback to 'User' if empty
        v_phone,
        v_delivery_group,  -- NULL by default unless provided
        CASE WHEN v_delivery_group IS NOT NULL THEN true ELSE false END,
        true
    );
    
    RETURN NEW;
EXCEPTION
    WHEN unique_violation THEN
        -- User already exists, ignore
        RETURN NEW;
    WHEN OTHERS THEN
        -- Log error but don't fail auth user creation
        RAISE WARNING 'Error creating user profile: %', SQLERRM;
        RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger on auth.users table
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_auth_user();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA auth TO postgres, authenticated, service_role;

-- ============================================
-- SUMMARY
-- ============================================
-- This migration:
-- 1. Removes unused create_user_profile RPC function
-- 2. Sets up clean RLS policies (no direct client INSERT allowed)
-- 3. Creates trigger to auto-create profiles from auth.users metadata
-- 4. Existing create_token_wallet_on_user_creation trigger will still work
--    (it triggers AFTER INSERT on public.users)
-- ============================================
