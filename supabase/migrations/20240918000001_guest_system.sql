-- Guest System Migration
-- This migration adds support for guest users who can try the service without signing up

-- Create guest profiles table
CREATE TABLE public.guest_profiles (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    trial_tokens INTEGER DEFAULT 3 NOT NULL,
    tokens_used INTEGER DEFAULT 0 NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '7 days') NOT NULL,
    is_active BOOLEAN DEFAULT true,
    
    -- Contact information (collected during checkout)
    first_name TEXT,
    last_name TEXT,
    phone TEXT,
    email TEXT,
    
    -- Conversion tracking
    converted_to_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    converted_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT guest_profiles_tokens_check CHECK (trial_tokens >= 0 AND tokens_used >= 0),
    CONSTRAINT guest_profiles_tokens_used_check CHECK (tokens_used <= trial_tokens),
    CONSTRAINT guest_profiles_phone_check CHECK (phone IS NULL OR phone ~ '^\+?[1-9]\d{1,14}$'),
    CONSTRAINT guest_profiles_email_check CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$')
);

-- Guest addresses (for delivery)
CREATE TABLE public.guest_addresses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    guest_id UUID REFERENCES public.guest_profiles(id) ON DELETE CASCADE NOT NULL,
    address_line_1 TEXT NOT NULL,
    address_line_2 TEXT,
    city TEXT NOT NULL,
    postal_code TEXT NOT NULL,
    country TEXT DEFAULT 'Denmark' NOT NULL,
    delivery_group delivery_group NOT NULL,
    delivery_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT guest_addresses_postal_code_check CHECK (postal_code ~ '^\d{4}$')
);

-- Guest carts (similar to user_carts but for guests)
CREATE TABLE public.guest_carts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    guest_id UUID REFERENCES public.guest_profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    menu_month_id UUID REFERENCES public.menu_months(id) ON DELETE CASCADE,
    delivery_address_id UUID REFERENCES public.guest_addresses(id) ON DELETE SET NULL,
    special_instructions TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Guest cart items
CREATE TABLE public.guest_cart_items (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    cart_id UUID REFERENCES public.guest_carts(id) ON DELETE CASCADE NOT NULL,
    dish_id UUID REFERENCES public.dishes(id) ON DELETE CASCADE NOT NULL,
    quantity INTEGER DEFAULT 1 NOT NULL,
    protein_option TEXT,
    special_requests TEXT,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT guest_cart_items_quantity_check CHECK (quantity > 0),
    UNIQUE(cart_id, dish_id, protein_option) -- Prevent duplicate items with same protein
);

-- Guest orders (similar to orders but for guests)
CREATE TABLE public.guest_orders (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    guest_id UUID REFERENCES public.guest_profiles(id) ON DELETE CASCADE NOT NULL,
    menu_month_id UUID REFERENCES public.menu_months(id) ON DELETE RESTRICT NOT NULL,
    delivery_address_id UUID REFERENCES public.guest_addresses(id) ON DELETE RESTRICT NOT NULL,
    status order_status DEFAULT 'pending' NOT NULL,
    total_tokens INTEGER NOT NULL,
    total_meals INTEGER NOT NULL,
    delivery_date DATE,
    delivery_group delivery_group NOT NULL,
    special_instructions TEXT,
    
    -- Guest specific fields
    guest_name TEXT NOT NULL, -- Combined first + last name for display
    guest_phone TEXT NOT NULL,
    guest_email TEXT,
    
    -- Tracking fields
    tracking_token UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL, -- For public order tracking
    
    -- Status timestamps
    confirmed_at TIMESTAMP WITH TIME ZONE,
    prepared_at TIMESTAMP WITH TIME ZONE,
    packed_at TIMESTAMP WITH TIME ZONE,
    out_for_delivery_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT guest_orders_totals_check CHECK (total_tokens > 0 AND total_meals > 0),
    CONSTRAINT guest_orders_phone_check CHECK (guest_phone ~ '^\+?[1-9]\d{1,14}$'),
    CONSTRAINT guest_orders_email_check CHECK (guest_email IS NULL OR guest_email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$')
);

-- Guest order items
CREATE TABLE public.guest_order_items (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    order_id UUID REFERENCES public.guest_orders(id) ON DELETE CASCADE NOT NULL,
    dish_id UUID REFERENCES public.dishes(id) ON DELETE RESTRICT NOT NULL,
    quantity INTEGER DEFAULT 1 NOT NULL,
    token_cost_per_item INTEGER NOT NULL,
    protein_option TEXT,
    special_requests TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT guest_order_items_quantity_check CHECK (quantity > 0),
    CONSTRAINT guest_order_items_token_cost_check CHECK (token_cost_per_item > 0)
);

-- Guest token transactions (for tracking token usage)
CREATE TABLE public.guest_token_transactions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    guest_id UUID REFERENCES public.guest_profiles(id) ON DELETE CASCADE NOT NULL,
    transaction_type token_transaction_type NOT NULL,
    amount INTEGER NOT NULL, -- Negative for token usage
    tokens_remaining INTEGER NOT NULL,
    description TEXT,
    reference_id UUID, -- Reference to guest order
    reference_type TEXT DEFAULT 'guest_order',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT guest_token_transactions_amount_check CHECK (amount != 0),
    CONSTRAINT guest_token_transactions_remaining_check CHECK (tokens_remaining >= 0)
);

-- Create indexes for performance
CREATE INDEX idx_guest_profiles_active ON public.guest_profiles(is_active, expires_at);
CREATE INDEX idx_guest_profiles_converted ON public.guest_profiles(converted_to_user_id);
CREATE INDEX idx_guest_addresses_guest_id ON public.guest_addresses(guest_id);
CREATE INDEX idx_guest_addresses_delivery_group ON public.guest_addresses(delivery_group);
CREATE INDEX idx_guest_carts_guest_id ON public.guest_carts(guest_id);
CREATE INDEX idx_guest_cart_items_cart_id ON public.guest_cart_items(cart_id);
CREATE INDEX idx_guest_orders_guest_id ON public.guest_orders(guest_id);
CREATE INDEX idx_guest_orders_status ON public.guest_orders(status);
CREATE INDEX idx_guest_orders_tracking_token ON public.guest_orders(tracking_token);
CREATE INDEX idx_guest_orders_delivery_date ON public.guest_orders(delivery_date);
CREATE INDEX idx_guest_order_items_order_id ON public.guest_order_items(order_id);
CREATE INDEX idx_guest_token_transactions_guest_id ON public.guest_token_transactions(guest_id);
CREATE INDEX idx_guest_token_transactions_created_at ON public.guest_token_transactions(created_at);

-- Function to create a new guest profile
CREATE OR REPLACE FUNCTION create_guest_profile()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    guest_id UUID;
BEGIN
    INSERT INTO public.guest_profiles (trial_tokens, tokens_used)
    VALUES (3, 0)
    RETURNING id INTO guest_id;
    
    RETURN guest_id;
END;
$$;

-- Function to use guest tokens
CREATE OR REPLACE FUNCTION use_guest_tokens(
    p_guest_id UUID,
    p_tokens_to_use INTEGER,
    p_order_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_tokens INTEGER;
    tokens_used INTEGER;
    tokens_remaining INTEGER;
BEGIN
    -- Get current token status
    SELECT trial_tokens, guest_profiles.tokens_used
    INTO current_tokens, tokens_used
    FROM public.guest_profiles
    WHERE id = p_guest_id AND is_active = true AND expires_at > NOW();
    
    IF NOT FOUND THEN
        RETURN FALSE; -- Guest not found or expired
    END IF;
    
    -- Check if enough tokens available
    IF (current_tokens - tokens_used) < p_tokens_to_use THEN
        RETURN FALSE; -- Not enough tokens
    END IF;
    
    -- Calculate remaining tokens after transaction
    tokens_remaining := current_tokens - tokens_used - p_tokens_to_use;
    
    -- Update guest profile
    UPDATE public.guest_profiles
    SET tokens_used = tokens_used + p_tokens_to_use,
        updated_at = NOW()
    WHERE id = p_guest_id;
    
    -- Record transaction
    INSERT INTO public.guest_token_transactions (
        guest_id, transaction_type, amount, tokens_remaining, 
        description, reference_id, reference_type
    ) VALUES (
        p_guest_id, 'order_deduction', -p_tokens_to_use, tokens_remaining,
        'Tokens used for guest order', p_order_id, 'guest_order'
    );
    
    RETURN TRUE;
END;
$$;

-- Function to convert guest to user
CREATE OR REPLACE FUNCTION convert_guest_to_user(
    p_guest_id UUID,
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update guest profile with conversion info
    UPDATE public.guest_profiles
    SET converted_to_user_id = p_user_id,
        converted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_guest_id AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- TODO: Migrate guest orders to user orders if needed
    -- This would be implemented based on business requirements
    
    RETURN TRUE;
END;
$$;

-- Function to cleanup expired guest profiles
CREATE OR REPLACE FUNCTION cleanup_expired_guests()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Deactivate expired guest profiles (keep data for analytics)
    UPDATE public.guest_profiles
    SET is_active = false,
        updated_at = NOW()
    WHERE expires_at < NOW() AND is_active = true;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;
