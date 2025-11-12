# Saturated Fat Implementation for EU Nutrition Label Compliance

## Overview
Added saturated fat tracking to meet EU/Romanian nutrition label requirements. Saturated fat is mandatory on EU nutrition labels and must be displayed as a sub-item under "Total Fat".

## Database Changes

### Migration: `20241021000001_add_saturated_fat_to_ingredients.sql`

**Changes:**
1. Added `saturated_fat_per_100g DECIMAL(6,2)` column to `ingredients` table
2. Updated `get_dish_nutrition()` function to:
   - Accept and return `saturated_fat` in the result
   - Calculate saturated fat from ingredient quantities
   - Scale properly based on per-100g values

**Function Signature:**
```sql
CREATE OR REPLACE FUNCTION public.get_dish_nutrition(p_dish_id UUID)
RETURNS TABLE (
    calories DECIMAL(10,2),
    protein DECIMAL(10,2),
    carbs DECIMAL(10,2),
    fat DECIMAL(10,2),
    saturated_fat DECIMAL(10,2),  -- NEW
    fiber DECIMAL(10,2),
    sugar DECIMAL(10,2),
    sodium DECIMAL(10,2),
    total_weight DECIMAL(10,2),
    is_vegan BOOLEAN,
    is_vegetarian BOOLEAN,
    is_gluten_free BOOLEAN,
    allergens TEXT[]
)
```

## Frontend Changes

### 1. TypeScript Types (`src/lib/supabase.ts`)

Added `saturated_fat_per_100g: number | null` to:
- `ingredients.Row`
- `ingredients.Insert`
- `ingredients.Update`

### 2. Admin Ingredients Page (`src/app/admin/ingredients/page.tsx`)

**State Management:**
- Added `saturatedFatPer100g: ''` to component state
- Updated all state reset locations (3 places)
- Added to `openEditModal()` function

**Database Operations:**
- Added `saturated_fat_per_100g` to `createIngredient()` call
- Added `saturated_fat_per_100g` to `updateIngredient()` call

**UI - Add Ingredient Modal:**
- Added "Saturated Fat (g)" input field
- Positioned after "Fat (g)" field
- Includes proper validation and step="0.1"

**UI - Edit Ingredient Modal:**
- Added "Saturated Fat (g)" input field
- Positioned after "Fat (g)" field
- Pre-fills with existing value when editing

### 3. Dish Detail Page (`src/app/menu/[id]/dish/[dishId]/page.tsx`)

**Nutrition Label:**
- Added "Saturated Fat" row in nutrition facts
- Positioned directly under "Total Fat" (indented with `pl-4`)
- Displays as `{nutrition.saturated_fat}g`
- Follows EU nutrition label format

## EU Compliance

### Romanian Nutrition Label Requirements (Met ✓)
1. ✅ Valoare energetică (Energy value) - Calories (kcal)
2. ✅ Grăsimi (Fat) - Fat (g)
3. ✅ **din care acizi grași saturați (Saturated fat)** - Saturated Fat (g) **[NEWLY ADDED]**
4. ✅ Glucide (Carbohydrates) - Carbs (g)
5. ✅ din care zaharuri (Sugars) - Sugar (g)
6. ✅ Fibre alimentare (Dietary fiber) - Fiber (g)
7. ✅ Proteine (Protein) - Protein (g)
8. ✅ Sare (Salt) - Salt (mg)

### Display Format
Following EU regulations, saturated fat is shown:
- As a sub-item under "Total Fat"
- Indented (using `pl-4` class)
- In the same format as other sub-items (fiber, sugar)

## Testing Checklist

### Database
- [ ] Run migration: `supabase migration up`
- [ ] Verify `saturated_fat_per_100g` column exists in `ingredients` table
- [ ] Test `get_dish_nutrition()` function returns saturated_fat value
- [ ] Verify calculation accuracy with known ingredient values

### Admin Side
- [ ] Add new ingredient with saturated fat value
- [ ] Edit existing ingredient to add saturated fat
- [ ] Verify saturated fat saves to database
- [ ] Check form validation works properly

### Client Side
- [ ] View dish nutrition label
- [ ] Verify "Saturated Fat" appears under "Total Fat"
- [ ] Confirm indentation matches EU format
- [ ] Check calculation accuracy for dishes with multiple ingredients

## Data Migration Notes

**Existing Ingredients:**
- All existing ingredients will have `saturated_fat_per_100g = NULL`
- Admins should update ingredient data with saturated fat values
- Dishes will show "0g" saturated fat until ingredients are updated

**Recommended Action:**
Update sample data in `20240901000004_sample_data.sql` to include realistic saturated fat values for existing ingredients.

## Files Modified

1. `supabase/migrations/20241021000001_add_saturated_fat_to_ingredients.sql` (NEW)
2. `frontend/my-app/src/lib/supabase.ts`
3. `frontend/my-app/src/app/admin/ingredients/page.tsx`
4. `frontend/my-app/src/app/menu/[id]/dish/[dishId]/page.tsx`

## Related Documentation

- EU Regulation 1169/2011 on food information to consumers
- Romanian nutrition labeling requirements (L170 EC)
- FDA nutrition label format (for reference)
