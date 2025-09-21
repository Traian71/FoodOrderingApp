-- Create root admin user migration
-- This migration creates a root admin user for initial system access

-- First, we need to create a user in auth.users table
-- Note: In production, this should be done through Supabase Auth Admin API
-- For development, we'll create a placeholder entry

-- Insert root admin user (you'll need to sign up with this email first through normal auth)
-- The email should match the one you use to sign up
INSERT INTO public.admin_users (
    id,
    email,
    first_name,
    last_name,
    role,
    is_active,
    created_at,
    updated_at
) VALUES (
    -- This UUID should match the auth.users.id after signup
    -- You'll need to update this with the actual UUID after creating the auth user
    '00000000-0000-0000-0000-000000000000'::uuid,
    'admin@simonsfreezermeals.com',
    'Root',
    'Admin',
    'root',
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    role = EXCLUDED.role,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Alternative approach: Create a function to automatically add admin role to specific emails
CREATE OR REPLACE FUNCTION public.handle_new_admin_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the new user's email should be an admin
    IF NEW.email IN ('admin@simonsfreezermeals.com', 'root@simonsfreezermeals.com', 'simon@simonsfreezermeals.com') THEN
        INSERT INTO public.admin_users (
            id,
            email,
            first_name,
            last_name,
            role,
            is_active,
            created_at,
            updated_at
        ) VALUES (
            NEW.id,
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'first_name', 'Admin'),
            COALESCE(NEW.raw_user_meta_data->>'last_name', 'User'),
            'root',
            true,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO NOTHING;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically add admin role for specific emails
DROP TRIGGER IF EXISTS on_auth_user_created_admin ON auth.users;
CREATE TRIGGER on_auth_user_created_admin
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_admin_user();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.handle_new_admin_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_admin_user() TO service_role;
