-- Add compound ingredient fields to ingredients table
ALTER TABLE ingredients
ADD COLUMN is_compound BOOLEAN DEFAULT FALSE,
ADD COLUMN subingredients TEXT;

-- Add comment for documentation
COMMENT ON COLUMN ingredients.is_compound IS 'Indicates if this ingredient is a compound ingredient made up of multiple subingredients';
COMMENT ON COLUMN ingredients.subingredients IS 'Text description of subingredients for compound ingredients (e.g., "flour, water, yeast, salt")';
