-- Fix user signup flow and remove delivery_group from user_addresses
-- Created: 2024-10-16
-- 
-- Issues fixed:
-- 1. New users should have group_assigned=false and delivery_group=null by default
-- 2. Only admin should assign delivery groups via admin dashboard
-- 3. user_addresses.delivery_group is redundant - users.delivery_group is the source of truth
-- 4. Remove delivery_group from user_addresses table

-- ============================================
-- PART 1: Update signup trigger to not set delivery_group
-- ============================================

-- Update the handle_new_auth_user function to always set group_assigned=false and delivery_group=null
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
BEGIN
    -- Extract metadata with proper null handling
    v_first_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'first_name', '')), '');
    v_last_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'last_name', '')), '');
    v_phone := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'phone', '')), '');
    
    -- Insert into public.users table
    -- New users always start with group_assigned=false and delivery_group=null
    -- Admin will assign delivery group later from admin dashboard
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
        NULL,  -- Always NULL - admin assigns later
        false, -- Always false - admin assigns later
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
-- PART 2: Remove delivery_group from user_addresses
-- ============================================

-- Drop the trigger that automatically sets delivery_group on user_addresses
DROP TRIGGER IF EXISTS set_delivery_group_trigger ON public.user_addresses;

-- Drop the function that sets delivery_group from postal code
DROP FUNCTION IF EXISTS public.set_delivery_group_from_postal_code();

-- Drop the index on delivery_group
DROP INDEX IF EXISTS public.idx_user_addresses_delivery_group;

-- Remove the delivery_group column from user_addresses
ALTER TABLE public.user_addresses 
DROP COLUMN IF EXISTS delivery_group;

-- ============================================
-- PART 3: Update TypeScript types comment
-- ============================================

-- Note: After running this migration, update the following files:
-- 1. frontend/my-app/src/lib/supabase.ts - Remove delivery_group from user_addresses types
-- 2. frontend/my-app/src/lib/database.ts - Update addressOperations to not use delivery_group
-- 3. frontend/my-app/src/app/account/profile/page.tsx - Remove delivery group display

-- ============================================
-- SUMMARY
-- ============================================
-- This migration:
-- 1. Updates signup trigger to always set group_assigned=false and delivery_group=null
-- 2. Removes delivery_group column from user_addresses table
-- 3. Removes related trigger and function for auto-setting delivery_group
-- 4. Users.delivery_group is now the single source of truth, assigned by admin only
-- ============================================
