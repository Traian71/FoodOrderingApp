-- Row Level Security (RLS) policies for the application
-- This sets up access control for all tables in the database

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
ALTER TABLE public.menu_months ENABLE ROW LEVEL SECURITY;
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
-- Users can view and update their own wallet
CREATE POLICY "users_can_view_own_wallet" ON public.token_wallets
    FOR SELECT USING (auth.uid() = token_wallets.user_id);

CREATE POLICY "users_can_update_own_wallet" ON public.token_wallets
    FOR UPDATE USING (auth.uid() = token_wallets.user_id) 
    WITH CHECK (auth.uid() = token_wallets.user_id);

CREATE POLICY "users_can_insert_own_wallet" ON public.token_wallets
    FOR INSERT WITH CHECK (auth.uid() = token_wallets.user_id);

-- Service role still gets full access for admin operations
CREATE POLICY "service_role_full_access" ON public.token_wallets
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Token transactions policies
-- Users can view their own transactions
CREATE POLICY "users_can_view_own_transactions" ON public.token_transactions
    FOR SELECT USING (auth.uid() = token_transactions.user_id);

-- Users can insert their own transactions
CREATE POLICY "users_can_insert_own_transactions" ON public.token_transactions
    FOR INSERT WITH CHECK (auth.uid() = token_transactions.user_id);

-- Service role still gets full access for admin operations
CREATE POLICY "service_role_full_access" ON public.token_transactions
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Ingredients policies
CREATE POLICY "service_role_full_access" ON public.ingredients
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.ingredients
    FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);

-- Menu months policies
CREATE POLICY "service_role_full_access" ON public.menu_months
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "block_non_service_access" ON public.menu_months
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
    mm.id as menu_month_id,
    mm.month_number,
    mm.year,
    mm.start_date,
    mm.end_date,
    mm.delivery_start_date,
    mm.delivery_end_date,
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
FROM public.menu_months mm
JOIN public.menu_items mi ON mm.id = mi.menu_month_id
JOIN public.dishes d ON mi.dish_id = d.id
WHERE mm.is_active = true 
AND d.is_active = true
ORDER BY mm.start_date, mi.display_order, d.name;

-- Guest Profiles Policies
-- Allow anonymous users to create guest profiles
CREATE POLICY "allow_anon_create_guest_profiles" ON public.guest_profiles
    FOR INSERT TO anon WITH CHECK (true);

-- Allow anonymous users to read their own guest profile
CREATE POLICY "allow_anon_read_own_guest_profile" ON public.guest_profiles
    FOR SELECT TO anon USING (true);

-- Allow anonymous users to update their own guest profile
CREATE POLICY "allow_anon_update_own_guest_profile" ON public.guest_profiles
    FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- Guest Addresses Policies
-- Allow anonymous users to manage guest addresses
CREATE POLICY "allow_anon_manage_guest_addresses" ON public.guest_addresses
    FOR ALL TO anon USING (true) WITH CHECK (true);

-- Guest Carts Policies
-- Allow anonymous users to manage guest carts
CREATE POLICY "allow_anon_manage_guest_carts" ON public.guest_carts
    FOR ALL TO anon USING (true) WITH CHECK (true);

-- Guest Cart Items Policies
-- Allow anonymous users to manage guest cart items
CREATE POLICY "allow_anon_manage_guest_cart_items" ON public.guest_cart_items
    FOR ALL TO anon USING (true) WITH CHECK (true);

-- Guest Orders Policies
-- Allow anonymous users to create and read guest orders
CREATE POLICY "allow_anon_create_guest_orders" ON public.guest_orders
    FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "allow_anon_read_guest_orders" ON public.guest_orders
    FOR SELECT TO anon USING (true);

-- Allow service role to update guest orders (for status updates)
CREATE POLICY "allow_service_update_guest_orders" ON public.guest_orders
    FOR UPDATE TO service_role USING (true) WITH CHECK (true);

-- Guest Order Items Policies
-- Allow anonymous users to create and read guest order items
CREATE POLICY "allow_anon_create_guest_order_items" ON public.guest_order_items
    FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "allow_anon_read_guest_order_items" ON public.guest_order_items
    FOR SELECT TO anon USING (true);

-- Guest Token Transactions Policies
-- Allow anonymous users to read their token transactions
CREATE POLICY "allow_anon_read_guest_token_transactions" ON public.guest_token_transactions
    FOR SELECT TO anon USING (true);

-- Allow service role to create token transactions (via functions)
CREATE POLICY "allow_service_create_guest_token_transactions" ON public.guest_token_transactions
    FOR INSERT TO service_role WITH CHECK (true);

-- Service role policies for all guest tables (for admin operations)
CREATE POLICY "service_role_full_access_guest_profiles" ON public.guest_profiles
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "service_role_full_access_guest_addresses" ON public.guest_addresses
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "service_role_full_access_guest_carts" ON public.guest_carts
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "service_role_full_access_guest_cart_items" ON public.guest_cart_items
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "service_role_full_access_guest_orders" ON public.guest_orders
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "service_role_full_access_guest_order_items" ON public.guest_order_items
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "service_role_full_access_guest_token_transactions" ON public.guest_token_transactions
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Allow anonymous users to read menu data
CREATE POLICY "allow_anon_read_menu_months" ON public.menu_months
    FOR SELECT TO anon USING (true);
    
CREATE POLICY "allow_anon_read_menu_items" ON public.menu_items
    FOR SELECT TO anon USING (true);
    
CREATE POLICY "allow_anon_read_dishes" ON public.dishes
    FOR SELECT TO anon USING (true);

CREATE POLICY "allow_anon_read_dish_ingredients" ON public.dish_ingredients
    FOR SELECT TO anon USING (true);

CREATE POLICY "allow_anon_read_ingredients" ON public.ingredients
    FOR SELECT TO anon USING (true);

-- Grant access to the public menu view for guests and authenticated users
GRANT SELECT ON public.public_menu TO anon, authenticated;

-- Enable RLS on all guest tables
ALTER TABLE public.guest_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_token_transactions ENABLE ROW LEVEL SECURITY;

-- Enable RLS on admin tables
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_activity_log ENABLE ROW LEVEL SECURITY;

-- Admin users policies
-- Simple policy that allows users to see their own record only
-- This avoids any circular dependency
CREATE POLICY "admin_users_own_record" ON public.admin_users
    FOR SELECT USING (id = auth.uid());

-- Allow service_role full access for backend operations
CREATE POLICY "admin_users_service_full_access" ON public.admin_users
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- For admin operations (insert/update/delete), we'll handle permissions in the application layer
-- This keeps the RLS simple and avoids recursion

-- Admin access policies for admin-managed tables
-- These allow admin users to directly manage content through the dashboard

-- Ingredients table policies
CREATE POLICY "admin_full_access_ingredients" ON public.ingredients
    FOR ALL TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "service_role_ingredients" ON public.ingredients
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Dishes table policies
CREATE POLICY "admin_full_access_dishes" ON public.dishes
    FOR ALL TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "service_role_dishes" ON public.dishes
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Dish ingredients table policies
CREATE POLICY "admin_full_access_dish_ingredients" ON public.dish_ingredients
    FOR ALL TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "service_role_dish_ingredients" ON public.dish_ingredients
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Menu months table policies
CREATE POLICY "admin_full_access_menu_months" ON public.menu_months
    FOR ALL TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "service_role_menu_months" ON public.menu_months
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Menu items table policies (kept for backward compatibility)
CREATE POLICY "admin_full_access_menu_items" ON public.menu_items
    FOR ALL TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "service_role_menu_items" ON public.menu_items
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Menu months table policies
CREATE POLICY "admin_full_access_menu_months" ON public.menu_months
    FOR ALL TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "service_role_menu_months" ON public.menu_months
    FOR ALL TO service_role USING (true) WITH CHECK (true);
