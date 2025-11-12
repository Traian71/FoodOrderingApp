-- Allow zero quantities for protein options and ingredients
-- Admins should be able to save incomplete data and come back later

-- Drop the existing constraint on dish_protein_options
ALTER TABLE public.dish_protein_options 
DROP CONSTRAINT IF EXISTS dish_protein_options_quantity_check;

-- Add new constraint that allows zero (>= 0 instead of > 0)
ALTER TABLE public.dish_protein_options 
ADD CONSTRAINT dish_protein_options_quantity_check 
CHECK (quantity >= 0);

-- Drop the existing constraint on dish_ingredients
ALTER TABLE public.dish_ingredients 
DROP CONSTRAINT IF EXISTS dish_ingredients_quantity_check;

-- Add new constraint that allows zero (>= 0 instead of > 0)
ALTER TABLE public.dish_ingredients 
ADD CONSTRAINT dish_ingredients_quantity_check 
CHECK (quantity >= 0);

-- Update comments
COMMENT ON COLUMN public.dish_protein_options.quantity IS 'Amount of this protein option needed per serving. Can be 0 if not yet determined.';
COMMENT ON COLUMN public.dish_ingredients.quantity IS 'Amount of this ingredient needed. Can be 0 if not yet determined.';
