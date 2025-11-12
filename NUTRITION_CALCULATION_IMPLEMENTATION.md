# Nutrition Calculation Implementation

## Overview
Implemented automatic nutrition facts calculation for dishes based on recipe ingredients. Nutrition data is calculated from the ingredients table and displayed on the client-side dish detail page.

## Implementation Details

### Database Layer

#### Migration: `20241010000007_add_dish_nutrition_calculation.sql`

**Function: `get_dish_nutrition(dish_id)`**
- Calculates nutrition facts from recipe ingredients
- Uses `dish_ingredients` quantities and `ingredients` nutrition per 100g
- Returns comprehensive nutrition data per serving

**Calculations:**
- **Macronutrients**: Calories, Protein, Carbs, Fat, Fiber, Sugar, Sodium
- **Total Weight**: Sum of all ingredient weights
- **Dietary Flags**: Vegan, Vegetarian, Gluten-Free (if ANY ingredient is not, dish is not)
- **Allergens**: Aggregated from all ingredients (deduplicated)

**Unit Conversion:**
- Handles: g, kg, ml, l
- Converts everything to grams for calculation
- Formula: `(nutrition_per_100g * quantity_in_grams) / 100`

**Example Calculation:**
```
Ingredient: Chicken (200g)
- Calories per 100g: 165 kcal
- Protein per 100g: 31g
- Contribution: (165 * 200) / 100 = 330 kcal, (31 * 200) / 100 = 62g protein
```

### Frontend Layer

#### Database Operations (`database.ts`)

**New Function:**
```typescript
dishOperations.getDishNutrition(dishId: string)
```
- Calls `get_dish_nutrition` RPC function
- Returns nutrition object with all calculated values

#### Dish Detail Page (`/menu/[id]/dish/[dishId]/page.tsx`)

**New State:**
- `nutrition` - Stores calculated nutrition data
- `nutritionLoading` - Loading state for nutrition fetch

**New Function:**
- `loadNutritionData()` - Fetches nutrition on page load
- Runs in parallel with dish data loading
- Errors are silently caught (nutrition is optional)

**Updated Nutrition Tab:**
- **FDA-Style Nutrition Label** - Professional black border design
- **Per Serving Information** - Shows total weight and serving size
- **Macronutrients Display**:
  - Calories (large, prominent)
  - Total Fat
  - Total Carbohydrate
  - Dietary Fiber (indented)
  - Total Sugars (indented)
  - Protein
  - Sodium
- **Dietary Information Section**:
  - Vegan badge 🌱
  - Vegetarian badge 🥬
  - Gluten Free badge 🌾
- **Allergen Warnings** - Red badges for all allergens
- **Serving Info Card** - Serving size, total weight, prep time

## User Experience

### Client Side (Dish Page)
1. User clicks on a dish
2. Dish details load immediately
3. Nutrition data loads in background
4. User clicks "Nutrition Facts" tab
5. Sees professional FDA-style nutrition label
6. Can view dietary flags and allergen warnings

### Admin Side
- **No changes** - Admin dish builder remains unchanged
- Nutrition is automatically calculated from ingredients
- No manual nutrition entry required

## Data Flow

```
1. Admin creates dish with ingredients
   ↓
2. Ingredients table has nutrition per 100g
   ↓
3. dish_ingredients table has quantities
   ↓
4. get_dish_nutrition() calculates totals
   ↓
5. Frontend displays on dish page
```

## Benefits

### Accuracy ✅
- Calculated from actual recipe ingredients
- No manual entry errors
- Updates automatically if recipe changes

### Compliance ✅
- Professional FDA-style nutrition label
- Consistent nutrition per serving
- Proper allergen warnings

### Automation ✅
- No admin work required
- Instant calculation
- Always up-to-date

### User Trust ✅
- Transparent ingredient-based calculation
- Professional presentation
- Clear allergen information

## Technical Details

### Database Schema Used

**Tables:**
- `ingredients` - Nutrition per 100g for each ingredient
- `dish_ingredients` - Recipe quantities
- `dishes` - Dish metadata

**Ingredient Nutrition Fields:**
- `calories_per_100g`
- `protein_per_100g`
- `carbs_per_100g`
- `fat_per_100g`
- `fiber_per_100g`
- `sugar_per_100g`
- `sodium_per_100g`
- `is_vegan`, `is_vegetarian`, `is_gluten_free`
- `common_allergens[]`

### Return Type

```typescript
{
  calories: number,
  protein: number,
  carbs: number,
  fat: number,
  fiber: number,
  sugar: number,
  sodium: number,
  total_weight: number,
  is_vegan: boolean,
  is_vegetarian: boolean,
  is_gluten_free: boolean,
  allergens: string[]
}
```

## Future Enhancements (Optional)

1. **Printable Labels** - Generate PDF nutrition labels
2. **Multiple Serving Sizes** - Show per 100g and per serving
3. **Micronutrients** - Add vitamins and minerals
4. **Daily Value %** - Calculate percentage of daily recommended values
5. **Nutrition Comparison** - Compare dishes side-by-side
6. **Export** - Download nutrition data as PDF/CSV

## Testing Checklist

### Database
- [ ] Run migration `20241010000007_add_dish_nutrition_calculation.sql`
- [ ] Verify function `get_dish_nutrition` exists
- [ ] Test with a sample dish that has ingredients
- [ ] Check unit conversion (g, kg, ml, l)
- [ ] Verify dietary flags work correctly
- [ ] Check allergen aggregation

### Frontend
- [ ] Navigate to a dish detail page
- [ ] Click "Nutrition Facts" tab
- [ ] Verify nutrition label displays correctly
- [ ] Check dietary badges appear (if applicable)
- [ ] Verify allergen warnings show (if applicable)
- [ ] Test with dish that has no ingredients (should show message)
- [ ] Check loading state works

### Integration
- [ ] Create a new dish with ingredients
- [ ] View nutrition facts immediately
- [ ] Modify ingredient quantities
- [ ] Verify nutrition updates automatically
- [ ] Test with various unit types (g, kg, ml)

## Files Modified/Created

**Database:**
- ✅ `supabase/migrations/20241010000007_add_dish_nutrition_calculation.sql`

**Frontend:**
- ✅ `frontend/my-app/src/lib/database.ts` (added `getDishNutrition`)
- ✅ `frontend/my-app/src/app/menu/[id]/dish/[dishId]/page.tsx` (updated nutrition tab)

## Summary

This implementation provides **automatic, accurate nutrition calculation** based on recipe ingredients. The system:
- Calculates nutrition from ingredient data (no manual entry)
- Displays professional FDA-style nutrition labels
- Shows dietary information and allergen warnings
- Requires no admin work (fully automated)
- Updates automatically when recipes change

The nutrition facts are displayed **only on the client-side dish page**, keeping the admin interface clean and focused on recipe management.
