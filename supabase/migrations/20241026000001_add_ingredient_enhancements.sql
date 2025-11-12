-- Migration: Add storage type and nutrition completion status to ingredients
-- Also add nutrition publish toggle to menu_items

-- Add new columns to ingredients table
ALTER TABLE ingredients
ADD COLUMN storage_type TEXT CHECK (storage_type IN ('raw', 'dried', 'frozen')) DEFAULT NULL,
ADD COLUMN nutrition_data_complete BOOLEAN DEFAULT false;

-- Add nutrition publish toggle to menu_items
ALTER TABLE menu_items
ADD COLUMN hide_nutrition_info BOOLEAN DEFAULT false;

-- Add comments to clarify the purpose
COMMENT ON COLUMN ingredients.storage_type IS 'Storage type for admin reference only (raw/dried/frozen)';
COMMENT ON COLUMN ingredients.nutrition_data_complete IS 'Admin tag to track completion of nutrition data entry - no impact on calculations';
COMMENT ON COLUMN menu_items.hide_nutrition_info IS 'When true, hides calculated nutrition info on dish page (shows only ingredients)';
