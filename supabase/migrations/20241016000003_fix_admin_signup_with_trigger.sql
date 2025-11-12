-- FIX ADMIN SIGNUP - Modify existing user trigger to handle admin signups too
-- This is the CORRECT approach - one trigger handles both regular and admin users

-- ============================================
-- PART 1: Clean up the old RPC function approach
-- ============================================

-- Drop the RPC function if it exists
DROP FUNCTION IF EXISTS public.create_admin_user_profile(UUID, TEXT, TEXT, TEXT, TEXT);

-- ============================================
-- PART 2: Modify existing trigger to handle BOTH regular and admin users
-- ============================================

-- Replace the existing handle_new_auth_user function to handle BOTH user types
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
    v_admin_role TEXT;
BEGIN
    -- Extract common metadata
    v_first_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'first_name', '')), '');
    v_last_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'last_name', '')), '');
    
    -- Check if this is an ADMIN signup (has admin_role in metadata)
    v_admin_role := NEW.raw_user_meta_data->>'admin_role';
    
    IF v_admin_role IS NOT NULL THEN
        -- This is an ADMIN signup - create admin_users record
        
        -- Validate role
        IF v_admin_role NOT IN ('root', 'admin', 'manager') THEN
            v_admin_role := 'admin';
        END IF;
        
        -- Insert into admin_users table
        INSERT INTO public.admin_users (
            id,
            email,
            first_name,
            last_name,
            role,
            is_active,
            created_at,
            updated_at
        )
        VALUES (
            NEW.id,
            NEW.email,
            COALESCE(v_first_name, 'Admin'),
            COALESCE(v_last_name, 'User'),
            v_admin_role,
            true,
            NOW(),
            NOW()
        );
        
    ELSE
        -- This is a REGULAR USER signup - create users record
        
        v_phone := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'phone', '')), '');
        
        -- Only set delivery_group if it's provided and valid
        IF NEW.raw_user_meta_data->>'delivery_group' IS NOT NULL 
           AND NEW.raw_user_meta_data->>'delivery_group' IN ('1', '2', '3', '4') THEN
            v_delivery_group := (NEW.raw_user_meta_data->>'delivery_group')::delivery_group;
        ELSE
            v_delivery_group := NULL;
        END IF;
        
        -- Insert into public.users table
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
            COALESCE(v_first_name, 'Unknown'),
            COALESCE(v_last_name, 'User'),
            v_phone,
            v_delivery_group,
            CASE WHEN v_delivery_group IS NOT NULL THEN true ELSE false END,
            true
        );
        
    END IF;
    
    RETURN NEW;
EXCEPTION
    WHEN unique_violation THEN
        -- Record already exists, ignore
        RETURN NEW;
    WHEN OTHERS THEN
        -- Log error but don't fail auth user creation
        RAISE WARNING 'Error creating user/admin profile: %', SQLERRM;
        RETURN NEW;
END;
$$;

-- The trigger already exists from the previous migration (on_auth_user_created)
-- No need to recreate it, just the function is updated

-- ============================================
-- SUMMARY
-- ============================================
-- This migration:
-- 1. Removes the old RPC function approach
-- 2. Updates the EXISTING handle_new_auth_user() function
-- 3. Function now checks for 'admin_role' in metadata
-- 4. If admin_role exists -> creates admin_users record
-- 5. If no admin_role -> creates regular users record (original behavior)
-- 6. One trigger handles everything!
-- ============================================
