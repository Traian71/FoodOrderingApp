# User Signup Fix - Cleanup Instructions

## Issues Fixed
1. ✅ First name and last name not being saved (was passing `full_name` instead)
2. ✅ Delivery group defaulting to '1' instead of NULL
3. ✅ Multiple redundant migration files created during debugging

## What to Do

### Step 1: Apply the Consolidated Migration
Run this migration in Supabase SQL Editor:
```
20241015000011_cleanup_and_fix_user_signup.sql
```

This migration:
- Removes the unused `create_user_profile` RPC function
- Sets up clean RLS policies (blocks direct client INSERT)
- Creates a trigger to auto-create user profiles from auth.users metadata
- Properly handles NULL values for first_name, last_name, phone, and delivery_group

### Step 2: Delete Redundant Migration Files (Optional)
These files were created during debugging and are now replaced by migration 011:
- `20241015000007_ensure_service_role_access.sql`
- `20241015000008_add_create_user_profile_function.sql`
- `20241015000009_fix_rls_for_signup.sql`
- `20241015000010_auto_create_user_profile.sql`

You can delete these files to keep the migrations folder clean.

### Step 3: Test Signup
Try creating a new user account. The flow should be:
1. User fills out signup form with first_name, last_name, phone, delivery_group
2. Frontend calls `auth.signUp()` with metadata
3. Supabase creates auth user
4. Trigger `on_auth_user_created` fires automatically
5. Trigger creates profile in `public.users` table with correct values
6. Existing trigger `create_token_wallet_on_user_creation` creates token wallet

## How It Works Now

### Database Trigger Approach
```
auth.users (INSERT) 
    ↓
on_auth_user_created trigger fires
    ↓
handle_new_auth_user() function runs with SECURITY DEFINER
    ↓
Inserts into public.users (bypasses RLS)
    ↓
create_token_wallet_on_user_creation trigger fires
    ↓
Creates token wallet
```

### Key Changes
- **Frontend**: Now passes `first_name` and `last_name` separately (not `full_name`)
- **Database**: Trigger properly extracts metadata and handles NULL values
- **RLS**: Blocks direct INSERT from client (only trigger can create users)
- **Defaults**: 
  - `first_name`: Falls back to 'Unknown' if empty
  - `last_name`: Falls back to 'User' if empty
  - `phone`: NULL if not provided
  - `delivery_group`: NULL if not provided or invalid
  - `group_assigned`: false if delivery_group is NULL, true otherwise

## Duplicate Migrations to Review

You also have duplicate admin access policies:
- `20241015000004_add_admin_access_policies.sql`
- `20241015000004_allow_admin_access_to_users.sql` (same timestamp!)

Consider consolidating these in a future cleanup.
