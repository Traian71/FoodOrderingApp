# Infinite Loading Fix - Tab Switching Issue

## Problem
When tabbing out and back to the browser on the admin orders page, the page would get stuck in an infinite "Loading admin dashboard..." state and require a manual refresh to work again.

## Root Cause
The issue was caused by multiple authentication checks being triggered when the browser tab becomes visible again:

1. **Browser Visibility Events**: When tabbing back, browsers may trigger token refresh or visibility change events
2. **Token Refresh Events**: Supabase's `TOKEN_REFRESHED` event was being handled but could trigger re-renders
3. **Duplicate Auth Checks**: AdminContext's `useEffect` was re-running on every dependency change without proper guards
4. **Redirect Timeouts**: Multiple redirect timeouts could be created, causing state conflicts
5. **Unnecessary Re-fetches**: The orders page was re-fetching data on every authentication state change

## Solution Applied

### 1. AdminContext.tsx - Prevent Duplicate Auth Checks
- Added `hasCheckedAuth` ref to track if authentication has been verified
- Added `isCheckingAuth` ref to prevent concurrent authentication checks
- Added early return if admin user is already set and unchanged
- Added `finally` block to always reset `isCheckingAuth` flag

**Key Changes:**
```typescript
const hasCheckedAuth = useRef(false)
const isCheckingAuth = useRef(false)

// Prevent duplicate checks
if (isCheckingAuth.current) return

// If we've already checked and have an admin user, don't check again
if (hasCheckedAuth.current && adminUser && user?.id === adminUser.id) {
  return
}
```

### 2. AuthContext.tsx - Prevent Re-initialization
- Added `hasInitialized` flag to prevent multiple initialization attempts
- Enhanced `TOKEN_REFRESHED` event handling with clear comment about preventing infinite loading
- Maintains current state on token refresh instead of re-fetching user data

**Key Changes:**
```typescript
let hasInitialized = false

const getInitialSession = async () => {
  if (hasInitialized) return
  hasInitialized = true
  // ... rest of initialization
}
```

### 3. Orders Page - Optimize Data Fetching
- Changed `useEffect` dependencies to only trigger on authentication state changes
- Removed `dataLoaded`, `fetchData`, and `weekFilter` from initial fetch dependencies
- Added eslint-disable comment to acknowledge intentional dependency optimization

**Key Changes:**
```typescript
// Only run when authentication state changes, not on every render
// eslint-disable-next-line react-hooks/exhaustive-deps
}, [adminLoading, isAuthenticated]);
```

## Technical Details

### Authentication Flow
1. **Initial Load**: AuthContext initializes once and fetches user data
2. **Admin Check**: AdminContext checks if user is admin (only once per user)
3. **Page Load**: Orders page fetches data when authenticated (only once)
4. **Tab Switch**: Token refresh maintains state without re-fetching
5. **Visibility Change**: No re-authentication or re-fetching occurs

### State Management
- **AuthContext**: Manages global authentication state
- **AdminContext**: Wraps admin pages and verifies admin access
- **DashboardContext**: Caches dashboard data with 5-minute TTL
- **Orders Page**: Fetches order-specific data independently

### Performance Optimizations
- Refs prevent duplicate async operations
- Early returns skip unnecessary checks
- Token refresh doesn't trigger user re-fetch
- Cached data reduces database load

## Testing Checklist
- [x] Tab out and back in - page should not reload
- [x] Manual refresh still works
- [x] Initial page load works correctly
- [x] Authentication redirects work
- [x] Week filter changes still trigger data refresh
- [x] Status filter changes work without re-fetch
- [x] Sign out redirects properly

## Files Modified
1. `frontend/my-app/src/contexts/AdminContext.tsx`
   - Added refs to prevent duplicate checks
   - Enhanced auth verification logic

2. `frontend/my-app/src/contexts/AuthContext.tsx`
   - Added initialization guard
   - Enhanced token refresh handling

3. `frontend/my-app/src/app/admin/orders/page.tsx`
   - Optimized useEffect dependencies
   - Prevented unnecessary re-fetches

## Related Issues
- Browser visibility API triggering re-authentication
- Supabase token refresh events causing state updates
- React useEffect dependency chains causing infinite loops
- Multiple concurrent authentication checks

## Prevention
To prevent similar issues in the future:
1. Always use refs to track async operation state
2. Add guards to prevent duplicate async operations
3. Be careful with useEffect dependencies
4. Don't re-fetch user data on token refresh
5. Use early returns to skip unnecessary work
6. Add initialization flags for one-time operations

## Date Fixed
2025-10-04
