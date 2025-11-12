-- Add policy to allow admin users to update their own last_login timestamp
-- This fixes the 406 error when admin users try to update their last login time

CREATE POLICY "admin_users_update_own_record" ON public.admin_users
    FOR UPDATE USING (id = auth.uid()) 
    WITH CHECK (id = auth.uid());
