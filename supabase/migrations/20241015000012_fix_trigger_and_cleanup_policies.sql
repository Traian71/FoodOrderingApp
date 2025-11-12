-- Fix the trigger function to properly handle metadata
-- and clean up any policies that were already created
-- Created: 2024-10-15

-- ============================================
-- PART 1: Drop any existing policies that might conflict
-- ============================================

DROP POLICY IF EXISTS "block_direct_insert" ON public.users;

-- ============================================
-- PART 2: Update the trigger function with proper null handling
-- ============================================

-- Replace the trigger function with corrected version
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

-- ============================================
-- SUMMARY
-- ============================================
-- This migration:
-- 1. Removes the block_direct_insert policy if it exists
-- 2. Updates the handle_new_auth_user() function with proper null handling
-- 3. Fixes the issue where first_name, last_name were empty
-- 4. Ensures delivery_group is NULL by default unless explicitly provided
-- ============================================
