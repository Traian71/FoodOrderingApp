-- Test if the function exists and check its signature
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'create_user_profile';

-- If the function exists, test calling it
-- SELECT public.create_user_profile(
--     'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid,
--     'test@example.com',
--     'Test',
--     'User',
--     NULL,
--     '1'
-- );
