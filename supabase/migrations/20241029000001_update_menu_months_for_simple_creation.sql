-- Update menu_months table to support simplified menu creation
-- This allows creating menus with just a name, configuring details later

-- Add name field for menu identification
ALTER TABLE public.menu_months 
ADD COLUMN name TEXT NOT NULL DEFAULT 'Untitled Menu';

-- Add configuration flag to track which menus need setup
ALTER TABLE public.menu_months 
ADD COLUMN is_configured BOOLEAN DEFAULT true;

-- Make existing fields nullable to allow unconfigured menus
-- This requires dropping constraints first, then making columns nullable

-- Drop existing constraints
ALTER TABLE public.menu_months 
DROP CONSTRAINT IF EXISTS menu_months_dates_check,
DROP CONSTRAINT IF EXISTS menu_months_delivery_dates_check,
DROP CONSTRAINT IF EXISTS menu_months_year_check,
DROP CONSTRAINT IF EXISTS menu_months_month_check,
DROP CONSTRAINT IF EXISTS menu_months_month_number_year_key;

-- Make columns nullable
ALTER TABLE public.menu_months 
ALTER COLUMN month_number DROP NOT NULL,
ALTER COLUMN year DROP NOT NULL,
ALTER COLUMN start_date DROP NOT NULL,
ALTER COLUMN end_date DROP NOT NULL,
ALTER COLUMN delivery_start_date DROP NOT NULL,
ALTER COLUMN delivery_end_date DROP NOT NULL,
ALTER COLUMN order_cutoff_date DROP NOT NULL;

-- Add new constraints that allow null values for unconfigured menus
ALTER TABLE public.menu_months 
ADD CONSTRAINT menu_months_dates_check CHECK (
    (start_date IS NULL AND end_date IS NULL) OR (start_date < end_date)
),
ADD CONSTRAINT menu_months_delivery_dates_check CHECK (
    (delivery_start_date IS NULL AND delivery_end_date IS NULL) OR (delivery_start_date <= delivery_end_date)
),
ADD CONSTRAINT menu_months_year_check CHECK (
    year IS NULL OR year >= 2024
),
ADD CONSTRAINT menu_months_month_check CHECK (
    month_number IS NULL OR month_number BETWEEN 1 AND 12
),
ADD CONSTRAINT menu_months_unique_configured CHECK (
    (month_number IS NULL OR year IS NULL) OR 
    (is_configured = true AND (month_number, year) IS NOT NULL)
);

-- Update existing menus to have proper names and be marked as configured
UPDATE public.menu_months 
SET name = CASE 
    WHEN month_number = 1 THEN 'January ' || year
    WHEN month_number = 2 THEN 'February ' || year
    WHEN month_number = 3 THEN 'March ' || year
    WHEN month_number = 4 THEN 'April ' || year
    WHEN month_number = 5 THEN 'May ' || year
    WHEN month_number = 6 THEN 'June ' || year
    WHEN month_number = 7 THEN 'July ' || year
    WHEN month_number = 8 THEN 'August ' || year
    WHEN month_number = 9 THEN 'September ' || year
    WHEN month_number = 10 THEN 'October ' || year
    WHEN month_number = 11 THEN 'November ' || year
    WHEN month_number = 12 THEN 'December ' || year
    ELSE 'Menu ' || id
END,
is_configured = true
WHERE name = 'Untitled Menu';

-- Add index for better performance on unconfigured menus
CREATE INDEX idx_menu_months_configured ON public.menu_months(is_configured, created_at);
