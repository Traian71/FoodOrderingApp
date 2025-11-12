-- Remove is_optional column from dish_ingredients table
-- This field is no longer needed as we're not using optional ingredients
-- Allow quantity to be 0 so admin can save incomplete recipes and come back later

-- First, drop the constraint that references is_optional
ALTER TABLE public.dish_ingredients 
DROP CONSTRAINT IF EXISTS dish_ingredients_quantity_check;

-- Remove the is_optional column
ALTER TABLE public.dish_ingredients 
DROP COLUMN IF EXISTS is_optional;

-- Add back the quantity check constraint (0 or positive, 0 means "to be determined")
ALTER TABLE public.dish_ingredients 
ADD CONSTRAINT dish_ingredients_quantity_check 
CHECK (quantity >= 0);

-- Update any NULL quantities to 0 (to be determined)
UPDATE public.dish_ingredients 
SET quantity = 0 
WHERE quantity IS NULL;

COMMENT ON TABLE public.dish_ingredients IS 'Recipe ingredients for dishes. Quantity can be 0 if not yet determined.';
