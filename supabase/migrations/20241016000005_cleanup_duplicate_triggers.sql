-- CLEANUP: Remove duplicate/broken admin trigger
-- We only need ONE trigger that handles both regular and admin users

-- Drop the broken admin trigger (it calls a function that doesn't exist)
DROP TRIGGER IF EXISTS on_auth_admin_user_created ON auth.users;

-- Drop the broken function if it exists
DROP FUNCTION IF EXISTS public.handle_new_admin_user();

-- The correct setup is:
-- 1. ONE trigger: on_auth_user_created
-- 2. ONE function: handle_new_auth_user() (which handles BOTH user types)
-- This was already set up in migration 20241016000003

-- Verify we only have one trigger now
DO $$
DECLARE
    trigger_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO trigger_count
    FROM information_schema.triggers
    WHERE event_object_table = 'users'
    AND event_object_schema = 'auth';
    
    RAISE NOTICE 'Number of triggers on auth.users: %', trigger_count;
    
    IF trigger_count != 1 THEN
        RAISE WARNING 'Expected 1 trigger on auth.users, found %', trigger_count;
    END IF;
END $$;
