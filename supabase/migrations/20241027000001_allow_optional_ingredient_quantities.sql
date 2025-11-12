-- Allow NULL quantities for optional ingredients in dish_ingredients table
-- This enables ingredients like spices to be added without specific quantities

-- Drop the existing constraint that requires quantity > 0
ALTER TABLE dish_ingredients 
DROP CONSTRAINT IF EXISTS dish_ingredients_quantity_check;

-- Add new constraint that allows NULL quantities for optional ingredients
-- But still requires quantity > 0 for non-optional ingredients
ALTER TABLE dish_ingredients 
ADD CONSTRAINT dish_ingredients_quantity_check 
CHECK (
  (is_optional = true AND quantity IS NULL) OR 
  (quantity IS NOT NULL AND quantity > 0)
);

-- Make quantity column nullable
ALTER TABLE dish_ingredients 
ALTER COLUMN quantity DROP NOT NULL;

-- Add comment to explain the logic
COMMENT ON CONSTRAINT dish_ingredients_quantity_check ON dish_ingredients IS 
'Optional ingredients can have NULL quantity, non-optional ingredients must have quantity > 0';
