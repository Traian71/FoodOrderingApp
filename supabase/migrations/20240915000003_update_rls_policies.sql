-- Update existing RLS policies to fix ambiguous column references
-- This fixes the "column reference 'current_balance' is ambiguous" error

-- Drop and recreate token_transactions policies with proper table qualification
DROP POLICY IF EXISTS "users_can_view_own_transactions" ON public.token_transactions;
DROP POLICY IF EXISTS "users_can_insert_own_transactions" ON public.token_transactions;

CREATE POLICY "users_can_view_own_transactions" ON public.token_transactions
    FOR SELECT USING (auth.uid() = token_transactions.user_id);

CREATE POLICY "users_can_insert_own_transactions" ON public.token_transactions
    FOR INSERT WITH CHECK (auth.uid() = token_transactions.user_id);

-- Drop and recreate token_wallets policies with proper table qualification
DROP POLICY IF EXISTS "users_can_view_own_wallet" ON public.token_wallets;
DROP POLICY IF EXISTS "users_can_update_own_wallet" ON public.token_wallets;
DROP POLICY IF EXISTS "users_can_insert_own_wallet" ON public.token_wallets;

CREATE POLICY "users_can_view_own_wallet" ON public.token_wallets
    FOR SELECT USING (auth.uid() = token_wallets.user_id);

CREATE POLICY "users_can_update_own_wallet" ON public.token_wallets
    FOR UPDATE USING (auth.uid() = token_wallets.user_id) WITH CHECK (auth.uid() = token_wallets.user_id);

CREATE POLICY "users_can_insert_own_wallet" ON public.token_wallets
    FOR INSERT WITH CHECK (auth.uid() = token_wallets.user_id);
