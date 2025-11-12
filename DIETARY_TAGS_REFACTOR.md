# Dietary Tags and Allergens Refactor

## Overview
Removed redundant `dietary_tags` and `allergens` columns from the `dishes` table. These values are now **computed dynamically from ingredients** on the client side, ensuring consistency and reducing manual data entry errors.

## Rationale
Since each ingredient already has:
- `is_vegan`, `is_vegetarian`, `is_gluten_free` flags
- `common_allergens` array

It makes no sense to manually specify dietary tags and allergens for each dish. The dish's properties should be **derived from its ingredients**.

## Changes Made

### 1. Database Schema
**Migration:** `20241021000002_remove_dietary_tags_and_allergens_from_dishes.sql`
- Removed `dietary_tags` column from `dishes` table
- Removed `allergens` column from `dishes` table
- Added table comment explaining the change

### 2. Helper Functions
**New File:** `src/lib/dishHelpers.ts`

Created utility functions to compute dietary properties:

- **`computeDietaryTags(ingredients)`** - Returns dietary tags (vegan, vegetarian, gluten-free) based on ALL ingredients
  - A dish is only vegan if ALL ingredients are vegan
  - A dish is only vegetarian if ALL ingredients are vegetarian
  - A dish is only gluten-free if ALL ingredients are gluten-free

- **`computeAllergens(ingredients)`** - Returns allergens present in ANY ingredient
  - A dish contains an allergen if ANY ingredient contains it
  - Returns sorted, deduplicated array

- **`getDietaryTagColor(tag)`** - Returns Tailwind CSS classes for badge styling
- **`getDietaryTagDisplay(tag)`** - Returns human-readable display name
- **`getAllergenDisplay(allergen)`** - Returns formatted allergen name

### 3. Admin Dish Builder
**File:** `src/app/admin/dish-builder/page.tsx`

**Removed:**
- Dietary tags selection UI section
- Allergens selection UI section
- `dietary_tags` and `allergens` from form state
- `toggleDietaryTag()` and `toggleAllergen()` handlers
- `dietary_tags` and `allergens` from dish creation database insert

**Result:** Admins now only need to:
1. Add ingredients to the dish
2. Specify quantities and preparation notes
3. The dietary tags and allergens are automatically computed from ingredients

### 4. Dish Detail Page
**File:** `src/app/menu/[id]/dish/[dishId]/page.tsx`

**Updated:**
- Removed `dietary_tags` and `allergens` from Dish type
- Added computed values using helper functions:
  ```typescript
  const dietaryTags = dish?.dish_ingredients ? computeDietaryTags(dish.dish_ingredients.map(di => di.ingredients)) : [];
  const allergens = dish?.dish_ingredients ? computeAllergens(dish.dish_ingredients.map(di => di.ingredients)) : [];
  ```
- Updated all display sections to use computed values
- Added proper styling with `getDietaryTagColor()` helper

### 5. Database Operations
**File:** `src/lib/database.ts`

**Updated `getDishWithMenuAvailability()`:**
- Enhanced ingredient query to include allergen and dietary information:
  ```sql
  ingredients (
    name,
    category,
    common_allergens,
    is_vegan,
    is_vegetarian,
    is_gluten_free
  )
  ```

## Benefits

### 1. **Data Consistency**
- No more mismatches between ingredient properties and dish tags
- Single source of truth (ingredients)
- Impossible to have incorrect dietary tags

### 2. **Reduced Manual Work**
- Admins don't need to manually select dietary tags
- Admins don't need to manually select allergens
- Less chance of human error

### 3. **Automatic Updates**
- If an ingredient's properties change, all dishes using it automatically reflect the change
- No need to update each dish individually

### 4. **Simplified Workflow**
- Dish builder form is cleaner and simpler
- Focus on what matters: ingredients and quantities
- Dietary information is automatically accurate

## Example

### Before:
Admin creates "Vegan Buddha Bowl":
1. ✅ Add quinoa, chickpeas, avocado, spinach
2. ❌ Manually select "vegan" tag
3. ❌ Manually check for allergens in each ingredient
4. ❌ Risk of forgetting to mark an allergen

### After:
Admin creates "Vegan Buddha Bowl":
1. ✅ Add quinoa, chickpeas, avocado, spinach
2. ✅ System automatically detects it's vegan (all ingredients are vegan)
3. ✅ System automatically detects allergens (e.g., sesame from tahini)
4. ✅ Always accurate, no manual work needed

## Computation Logic

### Dietary Tags (AND logic)
A dish has a dietary tag only if **ALL** ingredients have that property:
- **Vegan**: ALL ingredients must be vegan
- **Vegetarian**: ALL ingredients must be vegetarian  
- **Gluten-Free**: ALL ingredients must be gluten-free

### Allergens (OR logic)
A dish contains an allergen if **ANY** ingredient contains it:
- If any ingredient has "peanuts" in allergens → dish contains peanuts
- All allergens from all ingredients are combined and deduplicated

## Migration Instructions

1. **Run the migration:**
   ```bash
   supabase db push
   ```

2. **Verify the changes:**
   - Check that `dietary_tags` and `allergens` columns are removed from `dishes` table
   - Test dish detail pages to ensure dietary tags and allergens display correctly
   - Test admin dish builder to ensure it works without the removed fields

3. **No data loss:**
   - The columns are simply removed
   - All dietary information is now computed from ingredients
   - If ingredients are properly configured, the computed values will be accurate

## Future Considerations

- Consider adding more dietary tags (e.g., dairy-free, nut-free, keto, paleo)
- These can be added to the `computeDietaryTags()` function as needed
- All changes are centralized in `dishHelpers.ts`
