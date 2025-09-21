-- Fix RLS policies for direct frontend access to token_transactions
-- This allows authenticated users to access their own token transactions

-- Drop the restrictive policies on token_transactions
DROP POLICY IF EXISTS "service_role_full_access" ON public.token_transactions;
DROP POLICY IF EXISTS "block_non_service_access" ON public.token_transactions;

-- Create new policies that allow authenticated users to access their own data
CREATE POLICY "users_can_view_own_transactions" ON public.token_transactions
    FOR SELECT USING (auth.uid() = token_transactions.user_id);

CREATE POLICY "users_can_insert_own_transactions" ON public.token_transactions
    FOR INSERT WITH CHECK (auth.uid() = token_transactions.user_id);

-- Service role still gets full access for admin operations
CREATE POLICY "service_role_full_access" ON public.token_transactions
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Also fix token_wallets policies for consistency
DROP POLICY IF EXISTS "service_role_full_access" ON public.token_wallets;
DROP POLICY IF EXISTS "block_non_service_access" ON public.token_wallets;

CREATE POLICY "users_can_view_own_wallet" ON public.token_wallets
    FOR SELECT USING (auth.uid() = token_wallets.user_id);

CREATE POLICY "users_can_update_own_wallet" ON public.token_wallets
    FOR UPDATE USING (auth.uid() = token_wallets.user_id) WITH CHECK (auth.uid() = token_wallets.user_id);

CREATE POLICY "users_can_insert_own_wallet" ON public.token_wallets
    FOR INSERT WITH CHECK (auth.uid() = token_wallets.user_id);

-- Service role still gets full access for admin operations
CREATE POLICY "service_role_full_access" ON public.token_wallets
    FOR ALL TO service_role USING (true) WITH CHECK (true);
