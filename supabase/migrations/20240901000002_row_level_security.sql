-- Row Level Security (RLS) policies for backend-only access
-- This ensures all database operations go through the FastAPI backend
-- Uses service_role for backend access (the proven approach)

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_dietary_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_allergens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.token_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.token_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_weeks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dish_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_history ENABLE ROW LEVEL SECURITY;

-- Create policies using the proven service_role pattern
-- service_role gets full access, all others are blocked

-- Users table policies
CREATE POLICY "service_role_full_access" ON public.users
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.users
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- User addresses policies
CREATE POLICY "service_role_full_access" ON public.user_addresses
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.user_addresses
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- User dietary preferences policies
CREATE POLICY "service_role_full_access" ON public.user_dietary_preferences
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.user_dietary_preferences
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- User allergens policies
CREATE POLICY "service_role_full_access" ON public.user_allergens
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.user_allergens
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Subscription plans policies
CREATE POLICY "service_role_full_access" ON public.subscription_plans
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.subscription_plans
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- User subscriptions policies
CREATE POLICY "service_role_full_access" ON public.user_subscriptions
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.user_subscriptions
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Token wallets policies
CREATE POLICY "service_role_full_access" ON public.token_wallets
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.token_wallets
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Token transactions policies
CREATE POLICY "service_role_full_access" ON public.token_transactions
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.token_transactions
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Ingredients policies
CREATE POLICY "service_role_full_access" ON public.ingredients
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.ingredients
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Menu weeks policies
CREATE POLICY "service_role_full_access" ON public.menu_weeks
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.menu_weeks
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Dishes policies
CREATE POLICY "service_role_full_access" ON public.dishes
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.dishes
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Dish ingredients policies
CREATE POLICY "service_role_full_access" ON public.dish_ingredients
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.dish_ingredients
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Menu items policies
CREATE POLICY "service_role_full_access" ON public.menu_items
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.menu_items
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Orders policies
CREATE POLICY "service_role_full_access" ON public.orders
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.orders
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Order items policies
CREATE POLICY "service_role_full_access" ON public.order_items
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.order_items
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Delivery schedules policies
CREATE POLICY "service_role_full_access" ON public.delivery_schedules
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.delivery_schedules
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Billing history policies
CREATE POLICY "service_role_full_access" ON public.billing_history
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.billing_history
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Create a view for public menu data that can be accessed by guests
-- This allows the frontend to show menu data without authentication
CREATE OR REPLACE VIEW public.public_menu AS
SELECT 
    mw.id as menu_week_id,
    mw.week_number,
    mw.year,
    mw.start_date,
    mw.end_date,
    mw.delivery_start_date,
    mw.delivery_end_date,
    d.id as dish_id,
    d.name,
    d.description,
    d.prep_time_minutes,
    d.difficulty,
    d.dietary_tags,
    d.allergens,
    d.token_cost,
    d.available_protein_options as protein_options,
    mi.is_featured,
    mi.display_order
FROM public.menu_weeks mw
JOIN public.menu_items mi ON mw.id = mi.menu_week_id
JOIN public.dishes d ON mi.dish_id = d.id
WHERE mw.is_active = true 
AND d.is_active = true
ORDER BY mi.display_order, d.name;

-- Grant access to the public menu view for guests and authenticated users
GRANT SELECT ON public.public_menu TO anon, authenticated;

-- Enable RLS on admin tables
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_activity_log ENABLE ROW LEVEL SECURITY;

-- Admin users policies
CREATE POLICY "admin_users_select_policy" ON public.admin_users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.id = auth.uid() AND au.is_active = true
        )
    );

CREATE POLICY "admin_users_insert_policy" ON public.admin_users
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.id = auth.uid() AND au.role = 'root' AND au.is_active = true
        )
    );

CREATE POLICY "admin_users_update_policy" ON public.admin_users
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.id = auth.uid() AND au.is_active = true
            AND (au.role = 'root' OR au.id = admin_users.id)
        )
    );

CREATE POLICY "admin_users_delete_policy" ON public.admin_users
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.id = auth.uid() AND au.role = 'root' AND au.is_active = true
        )
        AND admin_users.id != auth.uid()
    );

-- Admin activity log policies
CREATE POLICY "admin_activity_log_select_policy" ON public.admin_activity_log
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.id = auth.uid() AND au.is_active = true
        )
    );

CREATE POLICY "admin_activity_log_insert_policy" ON public.admin_activity_log
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.id = auth.uid() AND au.is_active = true
        )
    );
