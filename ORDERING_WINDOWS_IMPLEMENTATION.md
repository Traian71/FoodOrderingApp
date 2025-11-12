# Ordering Windows Implementation Summary

## Overview
This document outlines the implementation of group-specific ordering windows for Simon's Freezer Meals platform. The system allows the admin to assign users to 4 delivery groups, and each group has its own ordering window for each menu month.

## Database Changes

### 1. Users Table (Already Exists + New Field)
- **`delivery_group`** (delivery_group enum, nullable) - Already added in migration `20241003000005`
- **`group_assigned`** (boolean, default false) - NEW field added in migration `20241007000002`

**User Flow:**
- New users have `group_assigned = false` and `delivery_group = null`
- Admin must assign user to a group (1-4) via admin users page
- Once assigned, `group_assigned = true` and `delivery_group` is set
- Users can only order if `group_assigned = true`

### 2. Menu Months Table (New Fields)
Added 8 new timestamp fields for ordering windows:
- `order_window_group1_start` / `order_window_group1_end`
- `order_window_group2_start` / `order_window_group2_end`
- `order_window_group3_start` / `order_window_group3_end`
- `order_window_group4_start` / `order_window_group4_end`

**Admin Flow:**
- When creating a menu, admin MUST input ordering windows for all 4 groups
- Each group gets a specific date/time range when they can place orders
- Example: Group 1 orders Week 1, Group 2 orders Week 2, etc.

### 3. Database Functions Created

#### `can_user_order_from_menu(p_user_id UUID, p_menu_month_id UUID)`
Returns `BOOLEAN` - checks if user can order from a specific menu right now.

**Logic:**
1. Check if user is assigned to a group (`group_assigned = true`)
2. Get user's delivery group
3. Check if current time is within that group's ordering window
4. Return true/false

#### `get_user_ordering_window(p_user_id UUID, p_menu_month_id UUID)`
Returns table with:
- `can_order` (boolean)
- `window_start` (timestamp)
- `window_end` (timestamp)
- `delivery_group` (enum)
- `group_assigned` (boolean)

**Usage:** Display to user when they can order and their group status.

## Frontend Changes

### 1. TypeScript Types Updated (`src/lib/supabase.ts`)
- ✅ Added `group_assigned` to users table types
- ✅ Made `delivery_group` nullable in users table
- ✅ Added 8 ordering window fields to menu_months table types

### 2. Database Operations (`src/lib/database.ts`)
- ✅ `userOperations.assignUserToGroup(userId, deliveryGroup)` - Assign user to group
- ✅ `userOperations.getAllUsers()` - Get all users for admin page
- ✅ `userOperations.getUserOrderingWindow(userId, menuMonthId)` - Get user's window info
- ✅ `userOperations.canUserOrder(userId, menuMonthId)` - Check if user can order
- ✅ `menuOperations.createMenuMonth()` - Updated to require ordering windows parameter

### 3. Admin Menu Page (`src/app/admin/menu/page.tsx`)
**Status:** PARTIALLY COMPLETE - needs finishing

**What's Done:**
- ✅ State updated to include `orderingWindows` array with start/end date/time for each group
- ✅ `handleCreateMenu` function signature updated

**What's Needed:**
- ⏳ Update Create Menu Modal UI to include ordering window inputs for all 4 groups
- ⏳ Add validation to ensure all ordering windows are filled before creating menu
- ⏳ Update Edit Menu Modal to allow editing ordering windows

### 4. Admin Users Page (`src/app/admin/users/page.tsx`)
**Status:** NOT STARTED

**What's Needed:**
- ⏳ Create users list view showing all users
- ⏳ Add "Assign to Group" button/dropdown for each user
- ⏳ Show current group assignment status (assigned/not assigned)
- ⏳ Add bulk assignment functionality
- ⏳ Display delivery_group and group_assigned status for each user

### 5. Customer Menu Page (`src/app/menu/[id]/page.tsx`)
**Status:** NOT STARTED

**What's Needed:**
- ⏳ Check user's ordering window on page load
- ⏳ Display ordering window information to user
- ⏳ Show countdown/timer for when ordering window opens/closes
- ⏳ Disable "Add to Cart" if outside ordering window
- ⏳ Show message if user is not assigned to a group
- ⏳ Redirect unassigned users with helpful message

### 6. Cart/Checkout Pages
**Status:** NOT STARTED

**What's Needed:**
- ⏳ Validate ordering window before allowing checkout
- ⏳ Show error if ordering window has closed during checkout process

## Migration Files

### Created:
1. ✅ `20241007000001_add_image_url_to_get_menu_dishes.sql` - Adds image_url to get_menu_dishes function
2. ✅ `20241007000002_add_ordering_windows_per_group.sql` - Adds ordering windows system

### To Apply:
```bash
cd c:\Users\tfm14\Work\Platforms\FoodOrderingApp
npx supabase db push
```

## Implementation Steps Remaining

### Step 1: Complete Admin Menu Creation Modal
Update `src/app/admin/menu/page.tsx` to add ordering window inputs in the Create Menu Modal.

**UI Structure Needed:**
```
Create New Menu Modal
├── Month & Year Selection (existing)
├── Ordering Windows Section (NEW)
│   ├── Group 1 Ordering Window
│   │   ├── Start Date & Time
│   │   └── End Date & Time
│   ├── Group 2 Ordering Window
│   │   ├── Start Date & Time
│   │   └── End Date & Time
│   ├── Group 3 Ordering Window
│   │   ├── Start Date & Time
│   │   └── End Date & Time
│   └── Group 4 Ordering Window
│       ├── Start Date & Time
│       └── End Date & Time
└── Delivery Schedules (existing)
```

### Step 2: Create Admin Users Page
Create `/admin/users` page with:
- User list table
- Group assignment dropdown for each user
- Status indicators (assigned/not assigned)
- Bulk assignment functionality

### Step 3: Update Customer Menu Page
Add ordering window checks and UI:
- Check if user is assigned to group
- Check if current time is within ordering window
- Display appropriate messages
- Disable ordering if outside window

### Step 4: Add Ordering Window Info Component
Create reusable component to show:
- User's delivery group
- Current ordering window dates
- Countdown timer
- Status (can order / cannot order / not assigned)

### Step 5: Testing
1. Apply migrations to database
2. Test admin menu creation with ordering windows
3. Test user group assignment
4. Test ordering window validation
5. Test edge cases (window transitions, unassigned users, etc.)

## Key Business Rules

1. **User Assignment Required:** Users CANNOT order until admin assigns them to a group
2. **All Windows Required:** Admin MUST set ordering windows for all 4 groups when creating a menu
3. **Window Enforcement:** Users can ONLY order during their group's ordering window
4. **One Group Per User:** Each user belongs to exactly one delivery group
5. **Admin Control:** Only admins can assign users to groups

## Database Schema Reference

```sql
-- Users table (relevant fields)
CREATE TABLE public.users (
    id UUID PRIMARY KEY,
    email TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    delivery_group delivery_group NULL,  -- '1', '2', '3', or '4'
    group_assigned BOOLEAN DEFAULT false,
    ...
);

-- Menu months table (relevant new fields)
CREATE TABLE public.menu_months (
    id UUID PRIMARY KEY,
    month_number INTEGER NOT NULL,
    year INTEGER NOT NULL,
    order_window_group1_start TIMESTAMP WITH TIME ZONE,
    order_window_group1_end TIMESTAMP WITH TIME ZONE,
    order_window_group2_start TIMESTAMP WITH TIME ZONE,
    order_window_group2_end TIMESTAMP WITH TIME ZONE,
    order_window_group3_start TIMESTAMP WITH TIME ZONE,
    order_window_group3_end TIMESTAMP WITH TIME ZONE,
    order_window_group4_start TIMESTAMP WITH TIME ZONE,
    order_window_group4_end TIMESTAMP WITH TIME ZONE,
    ...
);
```

## Next Actions

1. **Apply Database Migrations** (REQUIRED FIRST)
2. **Complete Admin Menu Modal** - Add ordering window inputs
3. **Create Admin Users Page** - For group assignment
4. **Update Customer Menu Page** - Add ordering window checks
5. **Test End-to-End Flow**
