# No Delivery Group Assigned - Ordering Prevention Fix

## Problem
Users who are not assigned to a delivery group (`group_assigned=false` or `delivery_group=null`) were able to browse menus but the system didn't properly prevent them from ordering or show clear messaging about why they couldn't order.

## Solution
Added comprehensive checks and user-friendly messaging throughout the ordering flow to handle users without assigned delivery groups.

## Changes Made

### 1. Database Function Update
**File:** `supabase/migrations/20241016000005_fix_ordering_window_no_group.sql`

Updated `get_user_ordering_window()` function to:
- Return data with `group_assigned=false` when user has no delivery group assigned
- Previously returned empty result, now returns proper data structure
- Allows frontend to detect unassigned users and show appropriate messages

**Key Logic:**
```sql
-- If user has no delivery group assigned, return with group_assigned=false
IF v_user_group IS NULL OR v_group_assigned = false THEN
    RETURN QUERY SELECT 
        false,
        NULL::TIMESTAMP WITH TIME ZONE,
        NULL::TIMESTAMP WITH TIME ZONE,
        v_user_group,
        COALESCE(v_group_assigned, false);
    RETURN;
END IF;
```

### 2. Menu Page Updates
**File:** `frontend/my-app/src/app/menu/[id]/page.tsx`

**Added:**
- Red alert banner when user has no delivery group assigned
- Clear messaging: "No Delivery Group Assigned"
- Explains that admin needs to assign delivery zone
- Separate amber alert for users outside their ordering window (existing functionality)

**Updated:**
- Dish cards now show "No Group Assigned" button when `orderingWindow` is null
- Quantity controls and add-to-cart disabled for unassigned users
- Proper conditional rendering based on `orderingWindow` existence

**UI Flow:**
1. If `!orderingWindow` → Show red "No Delivery Group Assigned" banner
2. If `orderingWindow && !orderingWindow.can_order && orderingWindow.group_assigned` → Show amber "Outside Ordering Window" banner
3. Dish buttons show appropriate disabled state with correct message

### 3. Dish Detail Page Updates
**File:** `frontend/my-app/src/app/menu/[id]/dish/[dishId]/page.tsx`

**Added:**
- Red alert box when user has no delivery group assigned
- Clear messaging explaining the situation
- Separate amber alert for users outside their ordering window

**Updated:**
- `handleAddToCart()` function checks for `!orderingWindow` first
- Shows alert: "You have not been assigned to a delivery group yet. Please contact an admin."
- Quantity controls disabled when no group assigned
- Add to cart button shows "No Group Assigned" when appropriate

**Validation Order:**
1. Check if `!orderingWindow` → User not assigned to group
2. Check if `orderingWindow && !orderingWindow.can_order` → Outside ordering window
3. Check token balance
4. Proceed with cart addition

## User Experience

### For Users Without Assigned Group:
- **Menu Page:** Red banner at top explaining they need group assignment
- **Dish Cards:** Disabled button showing "No Group Assigned"
- **Dish Detail:** Red alert box with explanation, disabled controls
- **Add to Cart:** Alert message if somehow triggered

### For Users Outside Ordering Window:
- **Menu Page:** Amber banner showing their group and window times
- **Dish Cards:** Disabled button showing "Outside Ordering Window"
- **Dish Detail:** Amber alert box with window details, disabled controls
- **Add to Cart:** Alert message about ordering window

### For Users Within Ordering Window:
- **Menu Page:** No alert banners
- **Dish Cards:** Active "View Details" button
- **Dish Detail:** All controls enabled
- **Add to Cart:** Fully functional

## Testing Checklist

- [ ] User with `group_assigned=false` sees red "No Delivery Group Assigned" banner
- [ ] User with `delivery_group=null` sees red banner
- [ ] Dish cards show "No Group Assigned" button (disabled) for unassigned users
- [ ] Dish detail page shows red alert for unassigned users
- [ ] Add to cart is blocked with appropriate alert message
- [ ] Quantity controls are disabled for unassigned users
- [ ] User with assigned group but outside window sees amber banner
- [ ] User with assigned group within window can order normally
- [ ] Database function returns proper data structure for all cases

## Database Migration

Run the migration to update the database function:
```bash
supabase db push
```

Or apply manually:
```bash
psql -f supabase/migrations/20241016000005_fix_ordering_window_no_group.sql
```

## Notes

- The `group_assigned` field in the `users` table is the source of truth
- Only admins can assign delivery groups via the admin dashboard
- Users can browse menus and view dishes regardless of group assignment
- Ordering is strictly prevented until group assignment
- Clear, user-friendly messaging explains the situation at every step
