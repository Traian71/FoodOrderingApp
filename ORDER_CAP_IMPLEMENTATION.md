# Order Cap Implementation Guide

## Overview
Successfully implemented a weekly order cap system for Simon's Freezer Meals platform. This allows admins to set maximum dish quantities per delivery group per ordering window.

## Implementation Details

### 1. Database Migration
**File:** `supabase/migrations/20241010000001_add_orders_cap_per_group.sql`

**Schema Changes:**
- Added 8 new columns to `menu_months` table:
  - `orders_cap_group1_initial` - Admin-set cap for group 1
  - `orders_cap_group1_remaining` - Current remaining capacity for group 1
  - `orders_cap_group2_initial` - Admin-set cap for group 2
  - `orders_cap_group2_remaining` - Current remaining capacity for group 2
  - `orders_cap_group3_initial` - Admin-set cap for group 3
  - `orders_cap_group3_remaining` - Current remaining capacity for group 3
  - `orders_cap_group4_initial` - Admin-set cap for group 4
  - `orders_cap_group4_remaining` - Current remaining capacity for group 4

**Database Functions Created:**
1. `admin_set_order_cap(menu_month_id, delivery_group, cap_value)` - Admin sets cap for a group
2. `reset_order_cap_for_group(menu_month_id, delivery_group)` - Resets remaining to initial value
3. `check_order_cap_available(menu_month_id, delivery_group, total_dishes)` - Validates order against cap
4. `get_remaining_order_cap(menu_month_id, delivery_group)` - Returns cap info
5. `deduct_from_order_cap(menu_month_id, delivery_group, total_dishes)` - Deducts from remaining cap

**Triggers:**
- `trigger_deduct_order_cap` - Automatically deducts from cap immediately when order is created (any status)
- `trigger_deduct_order_cap_guest` - Same for guest orders (any status)
- `trigger_restore_order_cap` - Restores cap when order status changes to cancelled
- `trigger_restore_order_cap_guest` - Same for guest orders

### 2. TypeScript Types
**File:** `frontend/my-app/src/lib/supabase.ts`

Updated `menu_months` table types to include all 8 new order cap fields in Row, Insert, and Update types.

### 3. Database Operations
**File:** `frontend/my-app/src/lib/database.ts`

**Enhanced `menuOperations` with:**
- `setOrderCap(menuMonthId, deliveryGroup, capValue)` - Set cap for a group
- `getRemainingOrderCap(menuMonthId, deliveryGroup)` - Get current cap status
- `checkOrderCapAvailable(menuMonthId, deliveryGroup, totalDishes)` - Validate before ordering
- `resetOrderCapForGroup(menuMonthId, deliveryGroup)` - Reset cap to initial value

**Updated `createMenuMonth()` function:**
- Added optional `orderCaps` parameter with group1Cap, group2Cap, group3Cap, group4Cap
- Sets both initial and remaining cap values when creating menu

### 4. Admin UI
**File:** `frontend/my-app/src/app/admin/menu/page.tsx`

**Form Updates:**
- Added `orderCaps` array to `newMenu` state with 4 group configurations
- Added "Order Caps per Group" section in create menu modal
- 2x2 grid layout with input fields for each group
- Optional fields (leave empty for no limit)
- Visual feedback with blue-themed styling

**User Experience:**
- Clear labeling: "Total dishes per window"
- Placeholder text: "No limit"
- Number input with min="0" validation
- Integrated seamlessly with existing form flow

## Workflow

### Admin Workflow:
1. **Create Menu:** Admin sets order cap when creating menu (optional)
2. **Cap Applied:** Both initial and remaining caps are set to the same value
3. **Auto-Deduction:** When orders are created (INSERT), total dishes are immediately deducted from remaining cap
4. **Validation:** Orders are rejected at creation time if they exceed remaining capacity
5. **Reset:** Cap resets to initial value when ordering window opens (manual trigger)

### User Workflow:
1. User adds dishes to cart
2. At checkout, system creates order (INSERT into orders table)
3. Trigger fires immediately and validates total dishes against remaining cap
4. If cap exceeded, order creation is blocked with error message
5. If cap available, order is created and cap is immediately deducted
6. If order status changes to 'cancelled' later, cap is restored

### Cap Reset Workflow:
When a new ordering window opens for a group, admin should call:
```typescript
await menuOperations.resetOrderCapForGroup(menuMonthId, deliveryGroup)
```

This can be automated with a scheduled job or triggered manually.

## Database Behavior

### NULL Values:
- If `orders_cap_groupX_initial` is NULL, no cap is enforced (unlimited ordering)
- If cap is set to 0, no orders can be placed

### Automatic Deduction:
- Triggers fire on INSERT to `orders` and `guest_orders` tables
- Deducts immediately when order is created, regardless of status
- Uses `total_meals` field from order to deduct
- BEFORE INSERT trigger means validation happens before order is saved

### Cancellation Handling:
- Triggers fire on UPDATE when status changes from any status to 'cancelled'
- Restores the `total_meals` back to remaining cap
- Prevents cap from being permanently consumed by cancelled orders
- Only restores if previous status was NOT 'cancelled' (prevents double restoration)

## Example Usage

### Setting Cap During Menu Creation:
```typescript
await menuOperations.createMenuMonth(
  11, // November
  2024,
  orderingWindows,
  deliveryDates,
  {
    group1Cap: 100,  // Group 1 can order max 100 dishes
    group2Cap: 150,  // Group 2 can order max 150 dishes
    group3Cap: null, // Group 3 has no limit
    group4Cap: 200   // Group 4 can order max 200 dishes
  }
)
```

### Checking Remaining Cap:
```typescript
const capInfo = await menuOperations.getRemainingOrderCap(menuMonthId, '1')
// Returns: { initial_cap: 100, remaining_cap: 73, cap_enabled: true }
```

### Validating Before Order:
```typescript
const canOrder = await menuOperations.checkOrderCapAvailable(menuMonthId, '1', 10)
// Returns: true if 10 dishes can be ordered, false otherwise
```

### Resetting Cap:
```typescript
await menuOperations.resetOrderCapForGroup(menuMonthId, '1')
// Resets group 1's remaining cap back to initial value
```

## Migration Instructions

1. **Run Migration:**
   ```bash
   supabase db push
   ```

2. **Verify Tables:**
   Check that `menu_months` table has the new columns

3. **Test Functions:**
   ```sql
   SELECT admin_set_order_cap('menu-id', '1', 100);
   SELECT * FROM get_remaining_order_cap('menu-id', '1');
   ```

4. **Update Frontend:**
   - TypeScript types are already updated
   - Database operations are ready to use
   - Admin UI includes cap settings in menu creation

## Notes

- Cap is per ordering window, not per month
- Each delivery group has independent caps
- Caps reset when ordering window opens (requires manual/automated trigger)
- NULL cap means unlimited ordering
- Triggers handle automatic deduction and restoration
- Works for both regular users and guest orders

## Future Enhancements

Consider implementing:
1. Automated cap reset when ordering windows open (cron job)
2. Admin dashboard showing cap usage in real-time
3. Alerts when caps are running low
4. Historical cap usage analytics
5. Per-dish caps in addition to total caps
