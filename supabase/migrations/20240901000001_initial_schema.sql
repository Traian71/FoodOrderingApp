-- Initial schema for Simon's Freezer Meals
-- This migration creates the core tables for the food ordering app

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create custom types
CREATE TYPE subscription_status AS ENUM ('active', 'paused', 'cancelled', 'pending');
CREATE TYPE subscription_plan AS ENUM ('8', '16', '24', '28');
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'preparing', 'packed', 'out_for_delivery', 'delivered', 'cancelled');
CREATE TYPE delivery_group AS ENUM ('1', '2', '3', '4');
CREATE TYPE dietary_preference AS ENUM ('vegan', 'vegetarian', 'pescatarian', 'meat');
CREATE TYPE token_transaction_type AS ENUM ('monthly_deposit', 'order_deduction', 'top_up', 'refund', 'adjustment');
CREATE TYPE difficulty_level AS ENUM ('easy', 'medium', 'hard');

-- Users table (extends Supabase auth.users)
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    phone TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    member_since TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    
    -- Constraints
    CONSTRAINT users_email_check CHECK (email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'),
    CONSTRAINT users_phone_check CHECK (phone IS NULL OR phone ~ '^\+?[1-9]\d{1,14}$')
);

-- User addresses
CREATE TABLE public.user_addresses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    address_line_1 TEXT NOT NULL,
    address_line_2 TEXT,
    city TEXT NOT NULL,
    postal_code TEXT NOT NULL,
    country TEXT DEFAULT 'Denmark' NOT NULL,
    delivery_group delivery_group NOT NULL,
    is_primary BOOLEAN DEFAULT false,
    delivery_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT user_addresses_postal_code_check CHECK (postal_code ~ '^\d{4}$')
);

-- User dietary preferences
CREATE TABLE public.user_dietary_preferences (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    dietary_preference dietary_preference NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Unique constraint to prevent duplicates
    UNIQUE(user_id, dietary_preference)
);

-- User allergens and food restrictions
CREATE TABLE public.user_allergens (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    allergen TEXT NOT NULL,
    severity TEXT, -- 'mild', 'severe', 'life-threatening'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, allergen)
);

-- Subscription plans (reference table)
CREATE TABLE public.subscription_plans (
    id subscription_plan PRIMARY KEY,
    name TEXT NOT NULL,
    meals_per_month INTEGER NOT NULL,
    price_eur INTEGER NOT NULL, -- Price in cents
    tokens_per_month INTEGER NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT subscription_plans_meals_check CHECK (meals_per_month > 0),
    CONSTRAINT subscription_plans_price_check CHECK (price_eur > 0),
    CONSTRAINT subscription_plans_tokens_check CHECK (tokens_per_month > 0)
);

-- User subscriptions
CREATE TABLE public.user_subscriptions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    plan_id subscription_plan REFERENCES public.subscription_plans(id) NOT NULL,
    status subscription_status DEFAULT 'pending' NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    paused_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    next_billing_date DATE NOT NULL,
    billing_cycle_day INTEGER DEFAULT 1, -- Day of month for billing
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT user_subscriptions_billing_day_check CHECK (billing_cycle_day BETWEEN 1 AND 28),
    CONSTRAINT user_subscriptions_dates_check CHECK (
        (status = 'paused' AND paused_at IS NOT NULL) OR 
        (status != 'paused' AND paused_at IS NULL)
    )
);

-- Token wallets
CREATE TABLE public.token_wallets (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    current_balance INTEGER DEFAULT 0 NOT NULL,
    max_balance INTEGER NOT NULL,
    last_deposit_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT token_wallets_balance_check CHECK (current_balance >= 0),
    CONSTRAINT token_wallets_max_balance_check CHECK (max_balance > 0),
    CONSTRAINT token_wallets_balance_limit_check CHECK (current_balance <= max_balance * 2) -- Allow some overflow for top-ups
);

-- Token transactions
CREATE TABLE public.token_transactions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    wallet_id UUID REFERENCES public.token_wallets(id) ON DELETE CASCADE NOT NULL,
    transaction_type token_transaction_type NOT NULL,
    amount INTEGER NOT NULL, -- Positive for credits, negative for debits
    balance_after INTEGER NOT NULL,
    description TEXT,
    reference_id UUID, -- Reference to order, subscription, etc.
    reference_type TEXT, -- 'order', 'subscription', 'top_up', etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT token_transactions_amount_check CHECK (amount != 0),
    CONSTRAINT token_transactions_balance_check CHECK (balance_after >= 0)
);

-- Ingredients database
CREATE TABLE public.ingredients (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    category TEXT, -- 'protein', 'vegetable', 'grain', 'dairy', etc.
    calories_per_100g DECIMAL(6,2),
    protein_per_100g DECIMAL(6,2),
    carbs_per_100g DECIMAL(6,2),
    fat_per_100g DECIMAL(6,2),
    fiber_per_100g DECIMAL(6,2),
    sugar_per_100g DECIMAL(6,2),
    sodium_per_100g DECIMAL(6,2),
    common_allergens TEXT[], -- Array of common allergens
    is_vegan BOOLEAN DEFAULT false,
    is_vegetarian BOOLEAN DEFAULT false,
    is_gluten_free BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT ingredients_nutrition_check CHECK (
        calories_per_100g IS NULL OR calories_per_100g >= 0
    )
);

-- Menu months
CREATE TABLE public.menu_months (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    month_number INTEGER NOT NULL, -- 1-12
    year INTEGER NOT NULL,
    start_date DATE NOT NULL, -- First day of the month
    end_date DATE NOT NULL, -- Last day of the month
    delivery_start_date DATE NOT NULL,
    delivery_end_date DATE NOT NULL,
    order_cutoff_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(month_number, year),
    CONSTRAINT menu_months_dates_check CHECK (start_date < end_date),
    CONSTRAINT menu_months_delivery_dates_check CHECK (delivery_start_date <= delivery_end_date),
    CONSTRAINT menu_months_year_check CHECK (year >= 2024),
    CONSTRAINT menu_months_month_check CHECK (month_number BETWEEN 1 AND 12)
);

-- Dishes
CREATE TABLE public.dishes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    preparation_instructions TEXT,
    prep_time_minutes INTEGER,
    difficulty difficulty_level DEFAULT 'medium',
    serving_size INTEGER DEFAULT 1,
    dietary_tags dietary_preference[] DEFAULT '{}',
    allergens TEXT[] DEFAULT '{}',
    available_protein_options TEXT[] DEFAULT '{}',
    token_cost INTEGER DEFAULT 1 NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT dishes_prep_time_check CHECK (prep_time_minutes IS NULL OR prep_time_minutes > 0),
    CONSTRAINT dishes_token_cost_check CHECK (token_cost > 0),
    CONSTRAINT dishes_serving_size_check CHECK (serving_size > 0)
);

-- Dish ingredients (recipe)
CREATE TABLE public.dish_ingredients (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    dish_id UUID REFERENCES public.dishes(id) ON DELETE CASCADE NOT NULL,
    ingredient_id UUID REFERENCES public.ingredients(id) ON DELETE RESTRICT NOT NULL,
    quantity DECIMAL(8,2) NOT NULL,
    unit TEXT NOT NULL, -- 'g', 'ml', 'pieces', etc.
    is_optional BOOLEAN DEFAULT false,
    preparation_note TEXT, -- 'diced', 'sliced', 'chopped', etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(dish_id, ingredient_id),
    CONSTRAINT dish_ingredients_quantity_check CHECK (quantity > 0)
);

-- Menu items (dishes available in specific months)
CREATE TABLE public.menu_items (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    menu_month_id UUID REFERENCES public.menu_months(id) ON DELETE CASCADE NOT NULL,
    dish_id UUID REFERENCES public.dishes(id) ON DELETE CASCADE NOT NULL,
    is_featured BOOLEAN DEFAULT false,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(menu_month_id, dish_id),
    CONSTRAINT menu_items_display_order_check CHECK (display_order >= 0)
);

-- Orders
CREATE TABLE public.orders (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    menu_month_id UUID REFERENCES public.menu_months(id) ON DELETE RESTRICT NOT NULL,
    delivery_address_id UUID REFERENCES public.user_addresses(id) ON DELETE RESTRICT NOT NULL,
    status order_status DEFAULT 'pending' NOT NULL,
    total_tokens INTEGER NOT NULL,
    total_meals INTEGER NOT NULL,
    delivery_date DATE,
    delivery_group delivery_group NOT NULL,
    special_instructions TEXT,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    prepared_at TIMESTAMP WITH TIME ZONE,
    packed_at TIMESTAMP WITH TIME ZONE,
    out_for_delivery_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT orders_totals_check CHECK (total_tokens > 0 AND total_meals > 0),
    CONSTRAINT orders_status_dates_check CHECK (
        (status = 'confirmed' AND confirmed_at IS NOT NULL) OR
        (status != 'confirmed' AND (confirmed_at IS NULL OR confirmed_at IS NOT NULL))
    )
);

-- Order items
CREATE TABLE public.order_items (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
    dish_id UUID REFERENCES public.dishes(id) ON DELETE RESTRICT NOT NULL,
    quantity INTEGER DEFAULT 1 NOT NULL,
    token_cost_per_item INTEGER NOT NULL,
    protein_option TEXT,
    special_requests TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT order_items_quantity_check CHECK (quantity > 0),
    CONSTRAINT order_items_token_cost_check CHECK (token_cost_per_item > 0)
);

-- Delivery schedules
CREATE TABLE public.delivery_schedules (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    delivery_group delivery_group NOT NULL,
    menu_month_id UUID REFERENCES public.menu_months(id) ON DELETE CASCADE NOT NULL,
    scheduled_date DATE NOT NULL,
    time_window_start TIME,
    time_window_end TIME,
    driver_notes TEXT,
    is_completed BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(delivery_group, menu_month_id),
    CONSTRAINT delivery_schedules_time_check CHECK (
        (time_window_start IS NULL AND time_window_end IS NULL) OR
        (time_window_start IS NOT NULL AND time_window_end IS NOT NULL AND time_window_start < time_window_end)
    )
);

-- Billing history
CREATE TABLE public.billing_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    subscription_id UUID REFERENCES public.user_subscriptions(id) ON DELETE CASCADE NOT NULL,
    amount_eur INTEGER NOT NULL, -- Amount in cents
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    payment_status TEXT DEFAULT 'pending' NOT NULL,
    payment_method TEXT,
    payment_reference TEXT,
    invoice_url TEXT,
    paid_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT billing_history_amount_check CHECK (amount_eur > 0),
    CONSTRAINT billing_history_period_check CHECK (billing_period_start < billing_period_end)
);

-- Create indexes for better performance
CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_user_addresses_user_id ON public.user_addresses(user_id);
CREATE INDEX idx_user_addresses_delivery_group ON public.user_addresses(delivery_group);
CREATE INDEX idx_user_subscriptions_user_id ON public.user_subscriptions(user_id);
CREATE INDEX idx_user_subscriptions_status ON public.user_subscriptions(status);
CREATE INDEX idx_token_wallets_user_id ON public.token_wallets(user_id);
CREATE INDEX idx_token_transactions_user_id ON public.token_transactions(user_id);
CREATE INDEX idx_token_transactions_created_at ON public.token_transactions(created_at);
CREATE INDEX idx_menu_months_active ON public.menu_months(is_active, start_date);
CREATE INDEX idx_menu_months_year_month ON public.menu_months(year, month_number);
CREATE INDEX idx_dishes_active ON public.dishes(is_active);
CREATE INDEX idx_dishes_dietary_tags ON public.dishes USING GIN(dietary_tags);
CREATE INDEX idx_menu_items_month_id ON public.menu_items(menu_month_id);
CREATE INDEX idx_orders_user_id ON public.orders(user_id);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_orders_delivery_date ON public.orders(delivery_date);
CREATE INDEX idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX idx_delivery_schedules_group_month ON public.delivery_schedules(delivery_group, menu_month_id);
CREATE INDEX idx_delivery_schedules_group_date ON public.delivery_schedules(delivery_group, scheduled_date);
CREATE INDEX idx_billing_history_user_id ON public.billing_history(user_id);

-- Admin role enum
CREATE TYPE admin_role AS ENUM ('root', 'admin', 'manager');

-- Admin users table (linked to auth.users)
CREATE TABLE public.admin_users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    role admin_role DEFAULT 'admin' NOT NULL,
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by_email TEXT,
    
    -- Constraints
    CONSTRAINT admin_users_email_check CHECK (email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$')
);

-- Admin activity log for audit trail
CREATE TABLE public.admin_activity_log (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    admin_user_id UUID REFERENCES public.admin_users(id) ON DELETE SET NULL,
    admin_email TEXT,
    action TEXT NOT NULL,
    resource_type TEXT,
    resource_id UUID,
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for admin tables
CREATE INDEX idx_admin_users_email ON public.admin_users(email);
CREATE INDEX idx_admin_users_role ON public.admin_users(role);
CREATE INDEX idx_admin_users_active ON public.admin_users(is_active);
CREATE INDEX idx_admin_activity_log_admin_user ON public.admin_activity_log(admin_user_id);
CREATE INDEX idx_admin_activity_log_created_at ON public.admin_activity_log(created_at);

-- User shopping carts
CREATE TABLE public.user_carts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    menu_month_id UUID REFERENCES public.menu_months(id) ON DELETE CASCADE,
    delivery_address_id UUID REFERENCES public.user_addresses(id) ON DELETE SET NULL,
    special_instructions TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Cart items
CREATE TABLE public.cart_items (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    cart_id UUID REFERENCES public.user_carts(id) ON DELETE CASCADE NOT NULL,
    dish_id UUID REFERENCES public.dishes(id) ON DELETE CASCADE NOT NULL,
    quantity INTEGER DEFAULT 1 NOT NULL,
    protein_option TEXT,
    special_requests TEXT,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT cart_items_quantity_check CHECK (quantity > 0),
    UNIQUE(cart_id, dish_id, protein_option) -- Prevent duplicate items with same protein
);

-- Indexes for cart tables
CREATE INDEX idx_user_carts_user_id ON public.user_carts(user_id);
CREATE INDEX idx_user_carts_menu_month ON public.user_carts(menu_month_id);
CREATE INDEX idx_cart_items_cart_id ON public.cart_items(cart_id);

-- Insert default subscription plans
INSERT INTO public.subscription_plans (id, name, meals_per_month, price_eur, tokens_per_month, description) VALUES
('8', '8 Meals Plan', 8, 11900, 8, 'Perfect for couples or light eaters'),
('16', '16 Meals Plan', 16, 19900, 16, 'Most popular - great for small families'),
('24', '24 Meals Plan', 24, 27900, 24, 'Ideal for larger families'),
('28', '28 Meals Plan', 28, 31900, 28, 'Maximum variety and convenience');
