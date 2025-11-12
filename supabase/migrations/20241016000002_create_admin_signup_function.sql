-- AUTO-CREATE ADMIN USER PROFILE VIA TRIGGER
-- This mirrors the regular user signup flow
-- When an auth user is created with admin metadata, automatically create admin profile

-- Function to automatically create admin profile when auth user is created with admin role
CREATE OR REPLACE FUNCTION public.handle_new_admin_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_first_name TEXT;
    v_last_name TEXT;
    v_role TEXT;
BEGIN
    -- Only process if this is an admin signup (has admin_role in metadata)
    IF NEW.raw_user_meta_data->>'admin_role' IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- Extract metadata
    v_first_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'first_name', '')), '');
    v_last_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'last_name', '')), '');
    v_role := COALESCE(NEW.raw_user_meta_data->>'admin_role', 'admin');
    
    -- Validate role
    IF v_role NOT IN ('root', 'admin', 'manager') THEN
        v_role := 'admin';
    END IF;
    
    -- Insert into admin_users table
    -- This runs with elevated privileges and bypasses RLS
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
        v_role,
        true,
        NOW(),
        NOW()
    );
    
    RETURN NEW;
EXCEPTION
    WHEN unique_violation THEN
        -- Admin user already exists, ignore
        RETURN NEW;
    WHEN OTHERS THEN
        -- Log error but don't fail auth user creation
        RAISE WARNING 'Error creating admin profile: %', SQLERRM;
        RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_admin_user_created ON auth.users;

-- Create trigger on auth.users table for admin signups
CREATE TRIGGER on_auth_admin_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_admin_user();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA auth TO postgres, authenticated, service_role;
