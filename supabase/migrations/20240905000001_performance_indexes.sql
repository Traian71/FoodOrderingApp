-- Performance optimization indexes for food ordering app
-- This migration adds critical indexes to improve API response times

-- Index for user_subscriptions queries (most critical)
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id_status 
ON user_subscriptions(user_id, status);

CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id_created_at 
ON user_subscriptions(user_id, created_at DESC);

-- Index for token_wallets queries
CREATE INDEX IF NOT EXISTS idx_token_wallets_user_id 
ON token_wallets(user_id);

-- Index for token_transactions queries (heavy read operations)
CREATE INDEX IF NOT EXISTS idx_token_transactions_user_id_created_at 
ON token_transactions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_token_transactions_wallet_id_created_at 
ON token_transactions(wallet_id, created_at DESC);

-- Index for billing_history queries
CREATE INDEX IF NOT EXISTS idx_billing_history_user_id_created_at 
ON billing_history(user_id, created_at DESC);

-- Index for subscription_plans (cached but still needs index)
CREATE INDEX IF NOT EXISTS idx_subscription_plans_is_active 
ON subscription_plans(is_active) WHERE is_active = true;

-- Composite index for the most common user subscription lookup
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_lookup 
ON user_subscriptions(user_id, status, created_at DESC) 
WHERE status IN ('active', 'paused');

-- Index for foreign key relationships to improve join performance
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_plan_id 
ON user_subscriptions(plan_id);

-- Add partial indexes for better performance on specific status queries
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_active 
ON user_subscriptions(user_id, next_billing_date) 
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_user_subscriptions_paused 
ON user_subscriptions(user_id, paused_at) 
WHERE status = 'paused';

-- Index for transaction types (for reporting and filtering)
CREATE INDEX IF NOT EXISTS idx_token_transactions_type_created_at 
ON token_transactions(transaction_type, created_at DESC);

-- Analyze tables to update statistics for query planner
ANALYZE user_subscriptions;
ANALYZE token_wallets;
ANALYZE token_transactions;
ANALYZE billing_history;
ANALYZE subscription_plans;
