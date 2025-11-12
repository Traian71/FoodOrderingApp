-- Fix double token deduction issue
-- The frontend is manually deducting tokens, but the database also has validation
-- This causes the order creation to fail after tokens are already deducted
-- Solution: Remove manual frontend deduction and add automatic deduction on order INSERT

-- Drop the old confirmation trigger (it only ran on UPDATE to 'confirmed')
DROP TRIGGER IF EXISTS deduct_tokens_on_confirmation ON public.orders;
DROP FUNCTION IF EXISTS deduct_tokens_on_order_confirmation();

-- Create new function to deduct tokens when order is INSERTED
CREATE OR REPLACE FUNCTION deduct_tokens_on_order_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Deduct tokens immediately when order is created
    INSERT INTO public.token_transactions (
        user_id,
        wallet_id,
        transaction_type,
        amount,
        balance_after,
        description,
        reference_id,
        reference_type
    )
    SELECT 
        NEW.user_id,
        tw.id,
        'order_deduction',
        -NEW.total_tokens,
        tw.current_balance - NEW.total_tokens,
        'Order #' || NEW.id || ' - ' || NEW.total_meals || ' meals',
        NEW.id,
        'order'
    FROM public.token_wallets tw
    WHERE tw.user_id = NEW.user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to deduct tokens when order is created
CREATE TRIGGER deduct_tokens_on_order_insert
    AFTER INSERT ON public.orders
    FOR EACH ROW EXECUTE FUNCTION deduct_tokens_on_order_insert();

-- Note: The validate_order_tokens_trigger (BEFORE INSERT) will check balance first
-- Then this trigger (AFTER INSERT) will deduct the tokens
-- The refund trigger on cancellation should still work correctly
