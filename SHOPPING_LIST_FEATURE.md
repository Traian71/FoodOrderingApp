# Shopping List Export Feature

## Overview
The shopping list feature automatically calculates ingredient quantities needed based on actual order volumes, with proper handling of protein options. This helps you know exactly how much of each ingredient to purchase for your cooking batches.

## How It Works

### Database Functions

**`get_shopping_list(start_date, end_date, delivery_group)`**
- Aggregates all ingredients needed across all orders in the date range
- Groups by ingredient and sums quantities
- Multiplies recipe quantities by number of orders
- Returns: ingredient name, category, total quantity, unit, and which dishes use it

**`get_shopping_list_by_dish(start_date, end_date, delivery_group)`**
- Organizes shopping list by dish batches
- Shows ingredients needed for each dish with protein options
- Multiplies recipe quantities by order count
- Returns: dish name, protein option, total orders, and ingredient breakdown

### Key Features

1. **Automatic Quantity Calculation**
   - If you have 100 orders for a dish that needs 150g salmon per portion
   - The system calculates: 100 × 150g = 15,000g (15kg) of salmon

2. **Protein Option Handling**
   - Dishes with different protein options are tracked separately
   - Example: "Chicken Bowl (Chicken)" vs "Chicken Bowl (Tofu)"
   - Each protein variant gets its own ingredient calculation

3. **Order Status Filtering**
   - Only includes confirmed, preparing, packed, and out_for_delivery orders
   - Excludes pending and cancelled orders for accurate counts

4. **Delivery Group Filtering**
   - Optional filter by delivery group (1, 2, 3, or 4)
   - Useful if you cook batches per delivery area

## Using the Feature

### In Admin Orders Dashboard

1. **Access**: Click the "Shopping List" button in the orders dashboard header
2. **Date Range**: Automatically uses your current week filter selection
   - "This Week" = shopping list for current week's orders
   - "Next Week" = shopping list for next week's orders
   - "All Upcoming" = complete shopping list for all upcoming orders

3. **Two View Modes**:

   **By Ingredient View**
   - Groups all ingredients by category (protein, vegetable, grain, etc.)
   - Shows total quantity needed across all dishes
   - Displays which dishes use each ingredient
   - Best for: Creating a master shopping list

   **By Dish View**
   - Organized by dish batches
   - Shows all ingredients needed for each specific dish
   - Includes protein option breakdown
   - Best for: Batch cooking preparation

4. **Export**: Click "Export CSV" to download the shopping list
   - Opens in Excel/Google Sheets
   - Ready for printing or sharing with suppliers

## Example Scenarios

### Scenario 1: Weekly Shopping
```
Week Filter: "This Week"
View: By Ingredient
Result: Complete shopping list for all orders this week
- Salmon: 15,250g (used in 3 dishes)
- Chicken Breast: 22,500g (used in 5 dishes)
- Quinoa: 8,400g (used in 2 dishes)
```

### Scenario 2: Batch Cooking
```
Week Filter: "Next Week"
View: By Dish
Result: Ingredient breakdown per dish batch
- Thai Green Curry (Chicken) - 73 orders
  - Chicken Breast: 180g × 73 = 13,140g
  - Coconut Milk: 250ml × 73 = 18,250ml
  - Curry Paste: 25g × 73 = 1,825g
```

### Scenario 3: Delivery Group Shopping
```
Week Filter: "This Week"
Delivery Group: Group 1 (Nørrebro/Østerbro)
Result: Shopping list only for Group 1 deliveries
```

## Technical Details

### Database Schema Integration
- Uses `order_items` table for order quantities
- Joins with `dish_ingredients` for recipe quantities
- Joins with `ingredients` for ingredient details
- Respects protein options from `dish_protein_options`

### Calculation Logic
```sql
total_quantity = recipe_quantity × number_of_orders

Example:
- Recipe: 150g salmon per dish
- Orders: 100 portions
- Result: 150 × 100 = 15,000g
```

### CSV Export Format

**By Ingredient:**
```csv
Ingredient,Category,Total Quantity,Unit,Used in # Dishes
Salmon,protein,15250,g,3
Chicken Breast,protein,22500,g,5
```

**By Dish:**
```csv
Thai Green Curry (Chicken),Orders: 73,"","",""
Ingredient,Category,Qty per Dish,Total Needed,Unit
Chicken Breast,protein,180,13140,g
Coconut Milk,dairy,250,18250,ml
```

## Best Practices

1. **Run Before Shopping**: Generate the list 1-2 days before your shopping trip
2. **Check Week Filter**: Make sure you're viewing the correct time period
3. **Use By Dish View**: When preparing batch cooking stations
4. **Use By Ingredient View**: When creating purchase orders for suppliers
5. **Export and Print**: Keep a physical copy in the kitchen during prep

## Future Enhancements

Potential improvements:
- Add supplier information to ingredients
- Include cost calculations
- Track inventory levels
- Generate purchase orders automatically
- Add waste/overage percentages for safety margins

## Files Modified

**Database:**
- `supabase/migrations/20241010000004_add_shopping_list_function.sql`

**Frontend:**
- `frontend/my-app/src/lib/database.ts` - Added shopping list operations
- `frontend/my-app/src/components/ShoppingListModal.tsx` - New modal component
- `frontend/my-app/src/app/admin/orders/page.tsx` - Integrated shopping list button

## Support

If you encounter issues:
1. Check that orders have confirmed status
2. Verify dishes have ingredients in `dish_ingredients` table
3. Ensure date range includes orders with delivery dates
4. Check browser console for error messages
