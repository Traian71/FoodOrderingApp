-- Create a trigger to automatically create user profile when auth user is created
-- This bypasses RLS issues by running with elevated privileges

-- Function to create user profile automatically
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insert into public.users table
    -- This runs with elevated privileges and bypasses RLS
    INSERT INTO public.users (
        id,
        email,
        first_name,
        last_name,
        phone,
        delivery_group,
        is_active
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
        NEW.raw_user_meta_data->>'phone',
        (NEW.raw_user_meta_data->>'delivery_group')::delivery_group,
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
