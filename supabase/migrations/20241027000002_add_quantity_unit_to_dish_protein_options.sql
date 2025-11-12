-- Add quantity and unit columns to dish_protein_options table
-- This allows admins to specify how much of each protein option is needed per serving
-- Quantity can be 0 or NULL if admin hasn't decided yet

-- Add columns to dish_protein_options (nullable to allow admin to fill in later)
ALTER TABLE public.dish_protein_options 
ADD COLUMN IF NOT EXISTS quantity DECIMAL(8,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'g';

-- Update existing records to have default values
UPDATE public.dish_protein_options 
SET quantity = 0 
WHERE quantity IS NULL;

UPDATE public.dish_protein_options 
SET unit = 'g' 
WHERE unit IS NULL;

-- Add constraint to ensure quantity is not negative (0 is allowed for "to be determined")
ALTER TABLE public.dish_protein_options 
ADD CONSTRAINT dish_protein_options_quantity_check 
CHECK (quantity >= 0);

-- Add comment explaining the purpose
COMMENT ON COLUMN public.dish_protein_options.quantity IS 'Amount of this protein option needed per serving (e.g., 200 for 200g of chicken). Can be 0 if not yet determined.';
COMMENT ON COLUMN public.dish_protein_options.unit IS 'Unit of measurement for the protein quantity (g, ml, pieces, etc.)';
