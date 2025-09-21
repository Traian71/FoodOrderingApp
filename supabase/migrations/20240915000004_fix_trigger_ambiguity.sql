-- Fix ambiguous column reference in process_token_transaction function
-- The issue is that the function declares a variable named 'current_balance' 
-- which conflicts with the column name in the SELECT statement

CREATE OR REPLACE FUNCTION process_token_transaction()
RETURNS TRIGGER AS $$
DECLARE
    wallet_balance INTEGER;  -- Renamed from current_balance to avoid conflict
    new_balance INTEGER;
BEGIN
    -- Get current wallet balance
    SELECT current_balance INTO wallet_balance
    FROM public.token_wallets
    WHERE user_id = NEW.user_id;
    
    -- Calculate new balance
    new_balance := wallet_balance + NEW.amount;
    
    -- Ensure balance doesn't go negative
    IF new_balance < 0 THEN
        RAISE EXCEPTION 'Insufficient token balance. Current: %, Requested: %', wallet_balance, ABS(NEW.amount);
    END IF;
    
    -- Update the balance_after field
    NEW.balance_after := new_balance;
    
    -- Update wallet balance
    UPDATE public.token_wallets
    SET current_balance = new_balance,
        updated_at = NOW(),
        last_deposit_date = CASE 
            WHEN NEW.transaction_type = 'monthly_deposit' THEN CURRENT_DATE
            ELSE last_deposit_date
        END
    WHERE user_id = NEW.user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
