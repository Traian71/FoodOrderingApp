-- ============================================
-- Rollback incorrect trigger and function
-- ============================================
-- Just drop what we created incorrectly

DROP TRIGGER IF EXISTS update_wallet_on_subscription_change ON public.user_subscriptions;
DROP FUNCTION IF EXISTS update_wallet_on_subscription();
