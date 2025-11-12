-- Update storage_type constraint to use 4 specific types
-- Fresh/raw, Dry, Canned/preserved, Frozen

-- Drop the old constraint
ALTER TABLE public.ingredients
DROP CONSTRAINT IF EXISTS ingredients_storage_type_check;

-- Migrate existing data to new values
UPDATE public.ingredients
SET storage_type = CASE
  WHEN storage_type = 'raw' THEN 'Fresh/raw'
  WHEN storage_type = 'dried' THEN 'Dry'
  WHEN storage_type = 'frozen' THEN 'Frozen'
  ELSE storage_type
END
WHERE storage_type IN ('raw', 'dried', 'frozen');

-- Add the new constraint with the 4 specified types
ALTER TABLE public.ingredients
ADD CONSTRAINT ingredients_storage_type_check 
CHECK (storage_type IN ('Fresh/raw', 'Dry', 'Canned/preserved', 'Frozen'));

-- Update the comment to reflect the new types
COMMENT ON COLUMN public.ingredients.storage_type IS 'Storage type for admin reference only (Fresh/raw, Dry, Canned/preserved, Frozen) - no impact on platform functionality';

