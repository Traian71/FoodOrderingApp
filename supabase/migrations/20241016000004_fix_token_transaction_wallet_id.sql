-- ============================================
-- Fix Token Transaction Missing wallet_id
-- ============================================
-- The token_transactions table requires wallet_id (NOT NULL)
-- but the trigger was not providing it

-- Drop the incorrect trigger and function
DROP TRIGGER IF EXISTS update_wallet_on_subscription_change ON public.user_subscriptions;
DROP FUNCTION IF EXISTS update_wallet_on_subscription();

-- Create corrected function that includes wallet_id in token transactions
CREATE OR REPLACE FUNCTION update_wallet_on_subscription()
RETURNS TRIGGER AS $$
DECLARE
    plan_tokens INTEGER;
    wallet_exists BOOLEAN;
    user_wallet_id UUID;
BEGIN
    -- Get tokens per month for the plan
    SELECT tokens_per_month INTO plan_tokens
    FROM public.subscription_plans
    WHERE id = NEW.plan_id;
    
    -- Check if wallet exists and get its ID
    SELECT id INTO user_wallet_id
    FROM public.token_wallets 
    WHERE user_id = NEW.user_id;
    
    wallet_exists := (user_wallet_id IS NOT NULL);
    
    -- Create wallet if it doesn't exist
    IF NOT wallet_exists THEN
        INSERT INTO public.token_wallets (user_id, current_balance, max_balance)
        VALUES (NEW.user_id, 0, plan_tokens)
        RETURNING id INTO user_wallet_id;
    END IF;
    
    -- For NEW subscriptions (INSERT), deposit the initial tokens
    IF TG_OP = 'INSERT' AND NEW.status = 'active' THEN
        UPDATE public.token_wallets
        SET 
            current_balance = plan_tokens,
            max_balance = plan_tokens,
            last_deposit_date = NOW(),
            updated_at = NOW()
        WHERE user_id = NEW.user_id;
        
        -- Record the token deposit transaction WITH wallet_id
        INSERT INTO public.token_transactions (
            user_id,
            wallet_id,
            transaction_type,
            amount,
            balance_after,
            description
        )
        VALUES (
            NEW.user_id,
            user_wallet_id,
            'monthly_deposit',
            plan_tokens,
            plan_tokens,
            'Initial token deposit for new subscription'
        );
    
    -- For subscription UPDATES (plan changes), update max_balance only
    ELSIF TG_OP = 'UPDATE' AND NEW.plan_id != OLD.plan_id THEN
        UPDATE public.token_wallets
        SET 
            max_balance = plan_tokens,
            updated_at = NOW()
        WHERE user_id = NEW.user_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
CREATE TRIGGER update_wallet_on_subscription_change
    AFTER INSERT OR UPDATE ON public.user_subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_wallet_on_subscription();
