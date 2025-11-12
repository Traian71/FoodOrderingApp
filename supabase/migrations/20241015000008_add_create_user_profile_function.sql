-- Create a secure function to handle user profile creation during signup
-- This function runs with SECURITY DEFINER to bypass RLS policies

CREATE OR REPLACE FUNCTION public.create_user_profile(
    user_id UUID,
    user_email TEXT,
    user_first_name TEXT,
    user_last_name TEXT,
    user_phone TEXT DEFAULT NULL,
    user_delivery_group TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    new_user JSONB;
BEGIN
    -- Insert the user profile
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
        user_id,
        user_email,
        user_first_name,
        user_last_name,
        user_phone,
        user_delivery_group::delivery_group,
        CASE WHEN user_delivery_group IS NOT NULL THEN true ELSE false END,
        true
    )
    RETURNING to_jsonb(users.*) INTO new_user;

    -- Create token wallet for the new user (trigger will handle this, but we ensure it exists)
    -- The trigger create_token_wallet_on_user_creation should handle this automatically
    
    RETURN new_user;
EXCEPTION
    WHEN unique_violation THEN
        -- User already exists, return existing user
        SELECT to_jsonb(users.*) INTO new_user
        FROM public.users
        WHERE id = user_id;
        RETURN new_user;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error creating user profile: %', SQLERRM;
END;
$$;

-- Grant execute permission to authenticated and anon users
GRANT EXECUTE ON FUNCTION public.create_user_profile(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon;

-- Add comment for documentation
COMMENT ON FUNCTION public.create_user_profile IS 
'Creates a user profile in the users table during signup. Runs with elevated privileges to bypass RLS.';

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
