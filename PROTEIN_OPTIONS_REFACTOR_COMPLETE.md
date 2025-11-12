# Protein Options Refactor - Complete Implementation Guide

## Overview
Successfully refactored the protein options system to use the `ingredients` table instead of a separate `is_protein_option` boolean. The system now uses `category='protein'` to identify protein ingredients.

## What Changed

### 1. Database Schema ✅

**Migration 1: `20241026000001_add_ingredient_enhancements.sql`**
- Added `storage_type` column to ingredients (raw/dried/frozen)
- Added `nutrition_data_complete` boolean to ingredients
- Added `hide_nutrition_info` boolean to menu_items
- **Removed**: `is_protein_option` boolean (not needed)

**Migration 2: `20241026000002_refactor_protein_options_to_ingredients.sql`**
- Refactored `dish_protein_options` table to reference `ingredients` instead of `protein_options`
- Old: `dish_protein_options.protein_option_id` → `protein_options.id`
- New: `dish_protein_options.ingredient_id` → `ingredients.id`
- Updated all functions and triggers to use ingredients table
- Migrated existing data from old structure to new

### 2. How Protein Options Work Now

**Identification:**
- Protein ingredients are identified by `category='protein'` in the ingredients table
- No special boolean flag needed

**Workflow for Creating Dishes with Protein Options:**
1. Admin creates a new dish
2. Admin adds all regular ingredients (vegetables, grains, spices, etc.)
3. Admin checks "Has protein options" checkbox
4. System shows all ingredients where `category='protein'`
5. Admin selects which protein ingredients are available for this dish
6. These selections are stored in `dish_protein_options` table

**When Customer Orders:**
1. Customer sees dish with available protein options
2. Protein options are fetched from: `dish_protein_options` → `ingredients` (where category='protein')
3. Customer selects their preferred protein
4. Selection stored as TEXT in `order_items.protein_option` and `cart_items.protein_option`

### 3. Database Functions Updated

All functions now use the new structure:

**`get_dish_protein_options(dish_uuid)`**
- Returns protein ingredients for a specific dish
- Joins: `dish_protein_options` → `ingredients` (where category='protein')

**`get_menu_dishes(menu_month_uuid, user_uuid)`**
- Returns dishes with their protein options array
- Protein options fetched from ingredients table

**`validate_cart_item_protein()`**
- Validates protein selection against dish's available protein ingredients
- Checks: `dish_protein_options` → `ingredients` (where category='protein')

**Cooking Batch Functions (No Changes Needed):**
- `start_dish_cooking_batch(dish_id, batch_date)` - Works with dish_id only
- `complete_dish_cooking_batch(dish_id, batch_date)` - Works with dish_id only
- `get_weekly_dish_summary(start_date, end_date)` - Aggregates by dish_id
- `get_admin_orders_with_cooking_status()` - Tracks by dish_id

**Why cooking functions don't need changes:**
- They work at the dish level, not protein level
- Protein selection is stored in `order_items.protein_option` as TEXT
- Cooking batches track "how many of this dish" not "how many with chicken vs beef"

### 4. Frontend Changes

**TypeScript Types (`supabase.ts`):**
- Removed `is_protein_option` from ingredients Row/Insert/Update types
- Added `storage_type` and `nutrition_data_complete`
- Added `hide_nutrition_info` to menu_items types

**Admin Ingredients Page:**
- Removed "Is Protein Option" toggle from Add/Edit modals
- Removed protein option badge from ingredient cards
- Kept storage type dropdown and nutrition complete toggle
- Protein ingredients are identified by their category='protein'

### 5. What You Need to Do

**Step 1: Run Migrations**
```sql
-- Run in order:
-- 1. 20241026000001_add_ingredient_enhancements.sql
-- 2. 20241026000002_refactor_protein_options_to_ingredients.sql
```

**Step 2: Verify Data Migration**
Check that existing protein options were migrated:
```sql
-- Should show all dishes with their protein ingredients
SELECT 
    d.name as dish_name,
    i.name as protein_name,
    i.category
FROM dish_protein_options dpo
JOIN dishes d ON d.id = dpo.dish_id
JOIN ingredients i ON i.id = dpo.ingredient_id
WHERE i.category = 'protein';
```

**Step 3: Create Protein Ingredients**
Make sure you have protein ingredients in the ingredients table:
```sql
-- Example: Add protein ingredients if they don't exist
INSERT INTO ingredients (name, category) VALUES
('Chicken', 'protein'),
('Beef', 'protein'),
('Pork', 'protein'),
('Fish', 'protein'),
('Tofu', 'protein'),
('Tempeh', 'protein'),
('Shrimp', 'protein')
ON CONFLICT (name) DO NOTHING;
```

**Step 4: Update Dish Creation UI**
You'll need to create/update the dish builder to:
1. Show "Has protein options" checkbox
2. When checked, display all ingredients where `category='protein'`
3. Allow admin to select multiple protein options
4. Save selections to `dish_protein_options` table

**Step 5: Clean Up (Optional)**
After verifying everything works:
```sql
-- Drop old backup table
DROP TABLE IF EXISTS dish_protein_options_old CASCADE;

-- Drop old protein_options table (if not used elsewhere)
DROP TABLE IF EXISTS protein_options CASCADE;
```

### 6. Key Benefits

**Simpler Architecture:**
- One less table to manage (`protein_options` can be removed)
- No duplicate data (protein info lives in ingredients table)
- Protein ingredients get all the benefits of ingredients (nutrition data, allergens, etc.)

**Better Data Consistency:**
- Protein options are actual ingredients with full nutritional data
- Can track protein allergens, dietary properties, etc.
- Storage type tracking for proteins (raw/frozen)

**Flexible Workflow:**
- Admin can filter ingredients by category='protein' when creating dishes
- Can add new protein types by simply adding ingredient with category='protein'
- No need for separate protein management interface

### 7. Current System State

**Tables:**
- `ingredients` - Contains all ingredients including proteins (category='protein')
- `dish_protein_options` - Junction table: dish_id → ingredient_id
- `order_items` - Stores selected protein as TEXT in `protein_option` column
- `cart_items` - Stores selected protein as TEXT in `protein_option` column

**No Changes Needed For:**
- Cooking batch system (works at dish level)
- Order processing (protein stored as TEXT)
- Cart functionality (protein stored as TEXT)
- Customer ordering flow (protein selection works the same)

**Frontend Ready:**
- TypeScript types updated
- Admin ingredients page updated
- No `is_protein_option` references remain

## Summary

The refactor is complete and ready for testing. The key insight is that **proteins are just ingredients with `category='protein'`**. No special boolean flag needed. The `dish_protein_options` table connects dishes to their available protein ingredients, and the cooking batch system doesn't care about proteins at all - it just tracks dishes.

Run the migrations, verify the data, and you're good to go!
