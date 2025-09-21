-- Migration: Convert weekly menu system to monthly menu system
-- This migration transforms menu_weeks to menu_months and updates all related tables

-- Step 1: Drop dependent views that reference menu_weeks columns
DROP VIEW IF EXISTS public_menu CASCADE;

-- Step 2: Create the new menu_months table
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

-- Step 3: Migrate existing data from menu_weeks to menu_months
-- Group weeks by month and create monthly entries
INSERT INTO public.menu_months (
    month_number,
    year,
    start_date,
    end_date,
    delivery_start_date,
    delivery_end_date,
    order_cutoff_date,
    is_active,
    created_at,
    updated_at
)
SELECT DISTINCT
    EXTRACT(MONTH FROM start_date)::INTEGER as month_number,
    year,
    DATE_TRUNC('month', start_date)::DATE as start_date,
    (DATE_TRUNC('month', start_date) + INTERVAL '1 month - 1 day')::DATE as end_date,
    MIN(delivery_start_date) as delivery_start_date,
    MAX(delivery_end_date) as delivery_end_date,
    MIN(order_cutoff_date) as order_cutoff_date,
    bool_or(is_active) as is_active, -- Month is active if any week was active
    MIN(created_at) as created_at,
    MAX(updated_at) as updated_at
FROM public.menu_weeks
GROUP BY EXTRACT(MONTH FROM start_date), year, DATE_TRUNC('month', start_date)
ORDER BY year, month_number;

-- Step 4: Create a temporary mapping table to track week-to-month relationships
CREATE TEMPORARY TABLE week_to_month_mapping AS
SELECT 
    mw.id as old_week_id,
    mm.id as new_month_id
FROM public.menu_weeks mw
JOIN public.menu_months mm ON (
    EXTRACT(MONTH FROM mw.start_date) = mm.month_number 
    AND mw.year = mm.year
);

-- Step 5: Update menu_items table to reference menu_months instead of menu_weeks
-- First, add the new column
ALTER TABLE public.menu_items ADD COLUMN menu_month_id UUID;

-- Update the new column with mapped values
UPDATE public.menu_items 
SET menu_month_id = wtmm.new_month_id
FROM week_to_month_mapping wtmm
WHERE menu_items.menu_week_id = wtmm.old_week_id;

-- Add foreign key constraint for the new column
ALTER TABLE public.menu_items 
ADD CONSTRAINT menu_items_menu_month_id_fkey 
FOREIGN KEY (menu_month_id) REFERENCES public.menu_months(id) ON DELETE CASCADE;

-- Make the new column NOT NULL
ALTER TABLE public.menu_items ALTER COLUMN menu_month_id SET NOT NULL;

-- Drop the old foreign key constraint and column (CASCADE to handle dependent views)
ALTER TABLE public.menu_items DROP CONSTRAINT menu_items_menu_week_id_dish_id_key;
ALTER TABLE public.menu_items DROP CONSTRAINT menu_items_menu_week_id_fkey;
ALTER TABLE public.menu_items DROP COLUMN menu_week_id CASCADE;

-- Remove duplicate menu items that would violate the unique constraint
-- Keep the one with the lowest display_order for each month/dish combination
DELETE FROM public.menu_items 
WHERE id NOT IN (
    SELECT DISTINCT ON (menu_month_id, dish_id) id
    FROM public.menu_items
    ORDER BY menu_month_id, dish_id, display_order ASC, created_at ASC
);

-- Add new unique constraint
ALTER TABLE public.menu_items ADD CONSTRAINT menu_items_menu_month_id_dish_id_key 
UNIQUE(menu_month_id, dish_id);

-- Step 6: Update orders table to reference menu_months
-- Add new column
ALTER TABLE public.orders ADD COLUMN menu_month_id UUID;

-- Update with mapped values
UPDATE public.orders 
SET menu_month_id = wtmm.new_month_id
FROM week_to_month_mapping wtmm
WHERE orders.menu_week_id = wtmm.old_week_id;

-- Add foreign key constraint
ALTER TABLE public.orders 
ADD CONSTRAINT orders_menu_month_id_fkey 
FOREIGN KEY (menu_month_id) REFERENCES public.menu_months(id) ON DELETE RESTRICT;

-- Make the new column NOT NULL
ALTER TABLE public.orders ALTER COLUMN menu_month_id SET NOT NULL;

-- Drop old constraint and column
ALTER TABLE public.orders DROP CONSTRAINT orders_menu_week_id_fkey;
ALTER TABLE public.orders DROP COLUMN menu_week_id CASCADE;

-- Step 7: Update delivery_schedules table
-- Add new column
ALTER TABLE public.delivery_schedules ADD COLUMN menu_month_id UUID;

-- Update with mapped values
UPDATE public.delivery_schedules 
SET menu_month_id = wtmm.new_month_id
FROM week_to_month_mapping wtmm
WHERE delivery_schedules.menu_week_id = wtmm.old_week_id;

-- Add foreign key constraint
ALTER TABLE public.delivery_schedules 
ADD CONSTRAINT delivery_schedules_menu_month_id_fkey 
FOREIGN KEY (menu_month_id) REFERENCES public.menu_months(id) ON DELETE CASCADE;

-- Make the new column NOT NULL
ALTER TABLE public.delivery_schedules ALTER COLUMN menu_month_id SET NOT NULL;

-- Drop old unique constraint and add new one
ALTER TABLE public.delivery_schedules DROP CONSTRAINT delivery_schedules_delivery_group_menu_week_id_key;
ALTER TABLE public.delivery_schedules ADD CONSTRAINT delivery_schedules_delivery_group_menu_month_id_key 
UNIQUE(delivery_group, menu_month_id);

-- Drop old constraint and column
ALTER TABLE public.delivery_schedules DROP CONSTRAINT delivery_schedules_menu_week_id_fkey;
ALTER TABLE public.delivery_schedules DROP COLUMN menu_week_id CASCADE;

-- Step 8: Update user_carts table
-- Add new column
ALTER TABLE public.user_carts ADD COLUMN menu_month_id UUID;

-- Update with mapped values (where applicable)
UPDATE public.user_carts 
SET menu_month_id = wtmm.new_month_id
FROM week_to_month_mapping wtmm
WHERE user_carts.menu_week_id = wtmm.old_week_id;

-- Add foreign key constraint
ALTER TABLE public.user_carts 
ADD CONSTRAINT user_carts_menu_month_id_fkey 
FOREIGN KEY (menu_month_id) REFERENCES public.menu_months(id) ON DELETE CASCADE;

-- Drop old constraint and column
ALTER TABLE public.user_carts DROP CONSTRAINT user_carts_menu_week_id_fkey;
ALTER TABLE public.user_carts DROP COLUMN menu_week_id CASCADE;

-- Step 9: Drop the old menu_weeks table
DROP TABLE public.menu_weeks CASCADE;

-- Step 10: Create indexes for the new menu_months table
CREATE INDEX idx_menu_months_active ON public.menu_months(is_active, start_date);
CREATE INDEX idx_menu_months_year_month ON public.menu_months(year, month_number);

-- Step 11: Update existing indexes that referenced menu_weeks
DROP INDEX IF EXISTS idx_menu_items_week_id;
CREATE INDEX idx_menu_items_month_id ON public.menu_items(menu_month_id);

DROP INDEX IF EXISTS idx_user_carts_menu_week;
CREATE INDEX idx_user_carts_menu_month ON public.user_carts(menu_month_id);

DROP INDEX IF EXISTS idx_delivery_schedules_group_date;
CREATE INDEX idx_delivery_schedules_group_month ON public.delivery_schedules(delivery_group, menu_month_id);

-- Step 12: Add helpful comments
COMMENT ON TABLE public.menu_months IS 'Monthly menu periods replacing the previous weekly system';
COMMENT ON COLUMN public.menu_months.month_number IS 'Month number (1-12)';
COMMENT ON COLUMN public.menu_months.year IS 'Year for this menu month';
COMMENT ON COLUMN public.menu_months.start_date IS 'First day of the month';
COMMENT ON COLUMN public.menu_months.end_date IS 'Last day of the month';
