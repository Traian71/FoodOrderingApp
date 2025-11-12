-- DEBUG: Check if trigger exists and test admin signup manually

-- First, let's see what triggers exist on auth.users
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'users'
AND event_object_schema = 'auth';

-- Check if the function exists
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'handle_new_auth_user';

-- Let's manually test creating an admin user
-- This simulates what should happen when someone signs up
DO $$
DECLARE
    test_id UUID := gen_random_uuid();
BEGIN
    -- Try to insert directly into admin_users
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
        test_id,
        'test@admin.com',
        'Test',
        'Admin',
        'admin',
        true,
        NOW(),
        NOW()
    );
    
    RAISE NOTICE 'Successfully created test admin user with ID: %', test_id;
    
    -- Clean up
    DELETE FROM public.admin_users WHERE id = test_id;
    RAISE NOTICE 'Cleaned up test admin user';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating admin user: %', SQLERRM;
END $$;
