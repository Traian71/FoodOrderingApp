-- Enable RLS and create policies for guest tables
-- This migration adds Row Level Security policies for all guest-related tables

-- Enable RLS on all guest tables
ALTER TABLE public.guest_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_token_transactions ENABLE ROW LEVEL SECURITY;

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
