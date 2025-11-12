-- Database triggers and functions for business logic
-- This migration creates automated triggers for token management, subscription logic, and data consistency

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_addresses_updated_at BEFORE UPDATE ON public.user_addresses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscription_plans_updated_at BEFORE UPDATE ON public.subscription_plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_subscriptions_updated_at BEFORE UPDATE ON public.user_subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_token_wallets_updated_at BEFORE UPDATE ON public.token_wallets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ingredients_updated_at BEFORE UPDATE ON public.ingredients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_menu_months_updated_at BEFORE UPDATE ON public.menu_months
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_dishes_updated_at BEFORE UPDATE ON public.dishes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_delivery_schedules_updated_at BEFORE UPDATE ON public.delivery_schedules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to create token wallet when user is created
CREATE OR REPLACE FUNCTION create_user_token_wallet()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.token_wallets (user_id, current_balance, max_balance)
    VALUES (NEW.id, 0, 16); -- Default to 16 meal plan max balance
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create token wallet for new users
CREATE TRIGGER create_token_wallet_on_user_creation
    AFTER INSERT ON public.users
    FOR EACH ROW EXECUTE FUNCTION create_user_token_wallet();

-- Function to update token wallet max balance when subscription changes
CREATE OR REPLACE FUNCTION update_wallet_max_balance()
RETURNS TRIGGER AS $$
DECLARE
    plan_tokens INTEGER;
BEGIN
    -- Get tokens per month for the new plan
    SELECT tokens_per_month INTO plan_tokens
    FROM public.subscription_plans
    WHERE id = NEW.plan_id;
    
    -- Update the wallet max balance
    UPDATE public.token_wallets
    SET max_balance = plan_tokens,
        updated_at = NOW()
    WHERE user_id = NEW.user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update wallet when subscription changes
CREATE TRIGGER update_wallet_on_subscription_change
    AFTER INSERT OR UPDATE ON public.user_subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_wallet_max_balance();

-- Function to process token transactions and update wallet balance
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

-- Trigger to process token transactions
CREATE TRIGGER process_token_transaction_trigger
    BEFORE INSERT ON public.token_transactions
    FOR EACH ROW EXECUTE FUNCTION process_token_transaction();

-- Function to validate order against token balance
CREATE OR REPLACE FUNCTION validate_order_tokens()
RETURNS TRIGGER AS $$
DECLARE
    wallet_balance INTEGER;
BEGIN
    -- Get current wallet balance
    SELECT current_balance INTO wallet_balance
    FROM public.token_wallets
    WHERE user_id = NEW.user_id;
    
    -- Check if user has enough tokens
    IF wallet_balance < NEW.total_tokens THEN
        RAISE EXCEPTION 'Insufficient tokens. Available: %, Required: %', wallet_balance, NEW.total_tokens;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to validate orders before creation
CREATE TRIGGER validate_order_tokens_trigger
    BEFORE INSERT ON public.orders
    FOR EACH ROW EXECUTE FUNCTION validate_order_tokens();

-- Function to deduct tokens when order is confirmed
CREATE OR REPLACE FUNCTION deduct_tokens_on_order_confirmation()
RETURNS TRIGGER AS $$
BEGIN
    -- Only deduct tokens when order status changes to 'confirmed'
    IF NEW.status = 'confirmed' AND (OLD.status IS NULL OR OLD.status != 'confirmed') THEN
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
            0, -- Will be calculated by the trigger
            'Order #' || NEW.id || ' - ' || NEW.total_meals || ' meals',
            NEW.id,
            'order'
        FROM public.token_wallets tw
        WHERE tw.user_id = NEW.user_id;
        
        -- Update order confirmation timestamp
        NEW.confirmed_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to deduct tokens when order is confirmed
CREATE TRIGGER deduct_tokens_on_confirmation
    BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION deduct_tokens_on_order_confirmation();

-- Function to refund tokens when order is cancelled
CREATE OR REPLACE FUNCTION refund_tokens_on_cancellation()
RETURNS TRIGGER AS $$
BEGIN
    -- Only refund tokens when order status changes to 'cancelled' from a confirmed state
    IF NEW.status = 'cancelled' AND OLD.status IN ('confirmed', 'preparing', 'packed') THEN
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
            'refund',
            NEW.total_tokens,
            0, -- Will be calculated by the trigger
            'Refund for cancelled order #' || NEW.id,
            NEW.id,
            'order_refund'
        FROM public.token_wallets tw
        WHERE tw.user_id = NEW.user_id;
        
        -- Update cancellation timestamp
        NEW.cancelled_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to refund tokens on order cancellation
CREATE TRIGGER refund_tokens_on_cancellation
    BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION refund_tokens_on_cancellation();

-- Function to ensure only one primary address per user
CREATE OR REPLACE FUNCTION ensure_single_primary_address()
RETURNS TRIGGER AS $$
BEGIN
    -- If setting this address as primary, unset all other primary addresses for this user
    IF NEW.is_primary = true THEN
        UPDATE public.user_addresses
        SET is_primary = false
        WHERE user_id = NEW.user_id AND id != NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to ensure single primary address
CREATE TRIGGER ensure_single_primary_address_trigger
    BEFORE INSERT OR UPDATE ON public.user_addresses
    FOR EACH ROW EXECUTE FUNCTION ensure_single_primary_address();

-- Function to calculate dish nutrition from ingredients
CREATE OR REPLACE FUNCTION calculate_dish_nutrition(dish_uuid UUID)
RETURNS TABLE (
    total_calories DECIMAL(8,2),
    total_protein DECIMAL(8,2),
    total_carbs DECIMAL(8,2),
    total_fat DECIMAL(8,2),
    total_fiber DECIMAL(8,2),
    total_sugar DECIMAL(8,2),
    total_sodium DECIMAL(8,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        SUM(COALESCE(i.calories_per_100g, 0) * di.quantity / 100) as total_calories,
        SUM(COALESCE(i.protein_per_100g, 0) * di.quantity / 100) as total_protein,
        SUM(COALESCE(i.carbs_per_100g, 0) * di.quantity / 100) as total_carbs,
        SUM(COALESCE(i.fat_per_100g, 0) * di.quantity / 100) as total_fat,
        SUM(COALESCE(i.fiber_per_100g, 0) * di.quantity / 100) as total_fiber,
        SUM(COALESCE(i.sugar_per_100g, 0) * di.quantity / 100) as total_sugar,
        SUM(COALESCE(i.sodium_per_100g, 0) * di.quantity / 100) as total_sodium
    FROM public.dish_ingredients di
    JOIN public.ingredients i ON di.ingredient_id = i.id
    WHERE di.dish_id = dish_uuid
    AND di.unit = 'g'; -- Only calculate for gram measurements
END;
$$ LANGUAGE plpgsql;

-- Function to get user's available tokens
CREATE OR REPLACE FUNCTION get_user_token_balance(user_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
    balance INTEGER;
BEGIN
    SELECT current_balance INTO balance
    FROM public.token_wallets
    WHERE user_id = user_uuid;
    
    RETURN COALESCE(balance, 0);
END;
$$ LANGUAGE plpgsql;

-- Function to check if user can order (has active subscription and tokens)
CREATE OR REPLACE FUNCTION can_user_order(user_uuid UUID, required_tokens INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    subscription_active BOOLEAN := false;
    token_balance INTEGER := 0;
BEGIN
    -- Check if user has active subscription
    SELECT EXISTS(
        SELECT 1 FROM public.user_subscriptions
        WHERE user_id = user_uuid 
        AND status = 'active'
    ) INTO subscription_active;
    
    -- Get token balance
    SELECT get_user_token_balance(user_uuid) INTO token_balance;
    
    RETURN subscription_active AND token_balance >= required_tokens;
END;
$$ LANGUAGE plpgsql;

-- Function to get delivery group for postal code
CREATE OR REPLACE FUNCTION get_delivery_group_for_postal_code(postal_code TEXT)
RETURNS delivery_group AS $$
BEGIN
    -- Simple mapping based on postal code ranges
    -- This should be customized based on actual delivery zones
    CASE 
        WHEN postal_code::INTEGER BETWEEN 1000 AND 2000 THEN RETURN '1';
        WHEN postal_code::INTEGER BETWEEN 2001 AND 3000 THEN RETURN '2';
        WHEN postal_code::INTEGER BETWEEN 3001 AND 4000 THEN RETURN '3';
        ELSE RETURN '4';
    END CASE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN '4'; -- Default to group 4 for invalid postal codes
END;
$$ LANGUAGE plpgsql;

-- Function to automatically set delivery group when address is created
CREATE OR REPLACE FUNCTION set_delivery_group_from_postal_code()
RETURNS TRIGGER AS $$
BEGIN
    NEW.delivery_group = get_delivery_group_for_postal_code(NEW.postal_code);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to set delivery group automatically
CREATE TRIGGER set_delivery_group_trigger
    BEFORE INSERT OR UPDATE ON public.user_addresses
    FOR EACH ROW EXECUTE FUNCTION set_delivery_group_from_postal_code();

-- Function to process monthly token deposits
CREATE OR REPLACE FUNCTION process_monthly_token_deposits()
RETURNS INTEGER AS $$
DECLARE
    processed_count INTEGER := 0;
    subscription_record RECORD;
    wallet_record RECORD;
    deposit_amount INTEGER;
    new_balance INTEGER;
BEGIN
    -- Process all active subscriptions that need token deposits
    FOR subscription_record IN
        SELECT us.*, sp.tokens_per_month
        FROM public.user_subscriptions us
        JOIN public.subscription_plans sp ON us.plan_id = sp.id
        WHERE us.status = 'active'
        AND us.next_billing_date <= CURRENT_DATE
    LOOP
        -- Get user's wallet
        SELECT * INTO wallet_record
        FROM public.token_wallets
        WHERE user_id = subscription_record.user_id;
        
        -- Calculate deposit amount (don't exceed max balance)
        deposit_amount := LEAST(
            subscription_record.tokens_per_month,
            wallet_record.max_balance - wallet_record.current_balance
        );
        
        -- Only deposit if there's room in the wallet
        IF deposit_amount > 0 THEN
            -- Create token transaction
            INSERT INTO public.token_transactions (
                user_id,
                wallet_id,
                transaction_type,
                amount,
                balance_after,
                description,
                reference_id,
                reference_type
            ) VALUES (
                subscription_record.user_id,
                wallet_record.id,
                'monthly_deposit',
                deposit_amount,
                0, -- Will be calculated by trigger
                'Monthly token deposit - ' || subscription_record.plan_id || ' meal plan',
                subscription_record.id,
                'subscription'
            );
            
            processed_count := processed_count + 1;
        END IF;
        
        -- Update next billing date
        UPDATE public.user_subscriptions
        SET next_billing_date = next_billing_date + INTERVAL '1 month'
        WHERE id = subscription_record.id;
    END LOOP;
    
    RETURN processed_count;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up expired menu months
CREATE OR REPLACE FUNCTION cleanup_expired_menu_months()
RETURNS INTEGER AS $$
DECLARE
    cleanup_count INTEGER;
BEGIN
    -- Mark menu months as inactive if they're more than 30 days old
    UPDATE public.menu_months
    SET is_active = false
    WHERE end_date < CURRENT_DATE - INTERVAL '30 days'
    AND is_active = true;
    
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RETURN cleanup_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get menu for specific month with user dietary preferences
CREATE OR REPLACE FUNCTION get_filtered_menu(
    menu_month_uuid UUID,
    user_uuid UUID DEFAULT NULL
)
RETURNS TABLE (
    dish_id UUID,
    dish_name TEXT,
    description TEXT,
    prep_time_minutes INTEGER,
    difficulty difficulty_level,
    dietary_tags dietary_preference[],
    allergens TEXT[],
    token_cost INTEGER,
    protein_options TEXT[],
    is_featured BOOLEAN,
    matches_preferences BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id,
        d.name,
        d.description,
        d.prep_time_minutes,
        d.difficulty,
        d.dietary_tags,
        d.allergens,
        d.token_cost,
        d.available_protein_options,
        mi.is_featured,
        CASE 
            WHEN user_uuid IS NULL THEN true
            ELSE EXISTS (
                SELECT 1 FROM public.user_dietary_preferences udp
                WHERE udp.user_id = user_uuid
                AND udp.dietary_preference = ANY(d.dietary_tags)
            )
        END as matches_preferences
    FROM public.menu_items mi
    JOIN public.dishes d ON mi.dish_id = d.id
    WHERE mi.menu_month_id = menu_month_uuid
    AND d.is_active = true
    ORDER BY mi.display_order, d.name;
END;
$$ LANGUAGE plpgsql;

-- Function to validate protein option in orders
CREATE OR REPLACE FUNCTION validate_protein_option()
RETURNS TRIGGER AS $$
BEGIN
    -- Skip validation if no protein option is selected
    IF NEW.protein_option IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- Check if the selected protein option is valid for this dish
    IF NOT EXISTS (
        SELECT 1 FROM public.dishes d
        WHERE d.id = NEW.dish_id
        AND NEW.protein_option = ANY(d.available_protein_options)
    ) THEN
        RAISE EXCEPTION 'Invalid protein option "%" for dish id %', NEW.protein_option, NEW.dish_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to validate protein options when orders are created
CREATE TRIGGER validate_protein_option_trigger
BEFORE INSERT OR UPDATE ON public.order_items
FOR EACH ROW EXECUTE FUNCTION validate_protein_option();

-- Admin helper functions
CREATE OR REPLACE FUNCTION is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.admin_users 
        WHERE id = user_id AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle new admin user creation
CREATE OR REPLACE FUNCTION public.handle_new_admin_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the new user's email should be an admin
    IF NEW.email IN ('admin@simonsfreezermeals.com', 'root@simonsfreezermeals.com', 'simon@simonsfreezermeals.com') THEN
        INSERT INTO public.admin_users (
            id,
            email,
            first_name,
            last_name,
            role,
            is_active,
            created_at,
            updated_at
        ) VALUES (
            NEW.id,
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'first_name', 'Admin'),
            COALESCE(NEW.raw_user_meta_data->>'last_name', 'User'),
            'root',
            true,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO NOTHING;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_role(user_id UUID)
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role 
    FROM public.admin_users 
    WHERE id = user_id AND is_active = true;
    
    RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION log_admin_activity(
    p_action TEXT,
    p_resource_type TEXT DEFAULT NULL,
    p_resource_id UUID DEFAULT NULL,
    p_details JSONB DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.admin_activity_log (
        admin_user_id,
        admin_email,
        action,
        resource_type,
        resource_id,
        details
    )
    SELECT 
        auth.uid(),
        au.email,
        p_action,
        p_resource_type,
        p_resource_id,
        p_details
    FROM public.admin_users au
    WHERE au.id = auth.uid() AND au.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for admin_users updated_at
CREATE TRIGGER update_admin_users_updated_at
    BEFORE UPDATE ON public.admin_users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger to automatically add admin role for specific emails
CREATE OR REPLACE FUNCTION setup_admin_trigger()
RETURNS void AS $$
BEGIN
    -- Drop the trigger if it exists to avoid duplicates
    DROP TRIGGER IF EXISTS on_auth_user_created_admin ON auth.users;
    
    -- Create the trigger
    EXECUTE 'CREATE TRIGGER on_auth_user_created_admin
        AFTER INSERT ON auth.users
        FOR EACH ROW EXECUTE FUNCTION public.handle_new_admin_user();';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the function to set up the trigger
SELECT setup_admin_trigger();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.handle_new_admin_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_admin_user() TO service_role;

-- Admin dashboard statistics functions
CREATE OR REPLACE FUNCTION get_total_members_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM public.users WHERE is_active = true);
END;
$$;

CREATE OR REPLACE FUNCTION get_active_subscriptions_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM public.user_subscriptions WHERE status = 'active');
END;
$$;

CREATE OR REPLACE FUNCTION get_pending_orders_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM public.orders WHERE status = 'pending');
END;
$$;

CREATE OR REPLACE FUNCTION get_completed_deliveries_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM public.orders WHERE status = 'delivered');
END;
$$;

CREATE OR REPLACE FUNCTION get_total_dishes_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM public.dishes WHERE is_active = true);
END;
$$;

CREATE OR REPLACE FUNCTION get_monthly_menus_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM public.menu_months WHERE is_active = true);
END;
$$;
