-- Debug script to check current RLS policies on users table
-- Run this in Supabase SQL Editor to see what policies exist

-- Show all policies on the users table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'users' 
ORDER BY policyname;

-- Check if the INSERT policy allows authenticated users to create their own profile
-- This should show a policy with cmd='INSERT' and roles containing 'authenticated'
