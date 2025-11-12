# Admin Authentication & Loading Fixes

## Issues Identified

### 1. **Authentication Race Conditions**
- Both `AuthContext` and `AdminContext` were checking authentication independently
- Admin pages (`/admin/orders`, `/admin/menu`) were using `useAuth()` hook which triggered duplicate auth checks
- This caused redirect loops: AdminContext redirects to login → login detects admin → redirects to admin → repeat

### 2. **Timeout Issues**
- Menu page had 10-second timeout that was too aggressive
- Orders page had 30-second timeout that still wasn't enough for large datasets
- Timeouts were causing "Request timeout" errors even when data was loading successfully

### 3. **Premature Data Fetching**
- Admin pages were trying to fetch data before `AdminContext` finished authentication
- This caused "loading forever" states because data fetch depended on incomplete auth

## Fixes Applied

### 1. **AdminContext Improvements** (`src/contexts/AdminContext.tsx`)
- **Fast-fail timeout**: Reduced to 3 seconds using `Promise.race()` pattern
- **Reliable redirects**: Use `window.location.href` instead of Next.js router for guaranteed redirects
- **Shorter redirect delay**: 500ms instead of 2 seconds to prevent user confusion
- **Better error handling**: Clear error messages and proper cleanup

```typescript
// Before: 5 second timeout with setTimeout
initializationTimeout = setTimeout(() => {
  setError('Authentication timeout - please refresh')
  setLoading(false)
}, 5000)

// After: 3 second timeout with Promise.race
const authPromise = auth.getCurrentAdminUser()
const timeoutPromise = new Promise<null>((resolve) => {
  initializationTimeout = setTimeout(() => {
    console.error('Admin initialization timeout after 3 seconds')
    resolve(null)
  }, 3000)
})
const currentAdmin = await Promise.race([authPromise, timeoutPromise])
```

### 2. **Orders Page Refactor** (`src/app/admin/orders/page.tsx`)
- **Removed duplicate auth**: Replaced `useAuth()` with `useAdmin()` hook
- **Removed premature auth checks**: Let `AdminContext` handle authentication and redirects
- **Increased data timeout**: 60 seconds for large order datasets
- **Proper loading states**: Show loading while `AdminContext` initializes
- **Fixed data fetching**: Only fetch when `isAuthenticated` is true

```typescript
// Before: Duplicate auth check
const { user, isAdmin } = useAuth();
useEffect(() => {
  if (!user || !isAdmin) {
    router.push('/login');
  }
}, [user, isAdmin, router]);

// After: Rely on AdminContext
const { adminUser, loading: adminLoading, isAuthenticated } = useAdmin();
useEffect(() => {
  if (!adminLoading && isAuthenticated && !dataLoaded) {
    fetchData();
  }
}, [adminLoading, isAuthenticated, dataLoaded]);
```

### 3. **Menu Page Refactor** (`src/app/admin/menu/page.tsx`)
- **Removed timeout**: Let database queries complete naturally
- **Added admin user check**: Only fetch when `adminUser` exists
- **Better dependency tracking**: Use `[adminLoading, adminUser]` in useEffect

```typescript
// Before: Aggressive 10-second timeout
const timeoutPromise = new Promise((_, reject) => 
  setTimeout(() => reject(new Error('Request timeout after 10 seconds')), 10000)
);
const allMenus = await Promise.race([
  menuOperations.getAllMenuMonths(),
  timeoutPromise
]);

// After: No timeout, let it complete
const allMenus = await menuOperations.getAllMenuMonths();
```

## Architecture Changes

### Authentication Flow
1. **Login Page**: User enters credentials
2. **AuthContext**: Handles sign-in, triggers auth state change
3. **Login Page useEffect**: Detects admin user, redirects to `/admin`
4. **ConditionalLayout**: Wraps `/admin` routes with `AdminProvider`
5. **AdminContext**: Authenticates admin user (3-second timeout)
6. **Admin Pages**: Wait for `isAuthenticated` before fetching data

### Key Principles
- **Single Source of Truth**: Admin pages only use `AdminContext`, not `AuthContext`
- **Fast Failure**: 3-second timeout prevents infinite loading
- **Reliable Redirects**: Use `window.location.href` for critical redirects
- **Proper Loading States**: Show loading UI while auth initializes
- **No Premature Fetching**: Wait for authentication before data requests

## Testing Checklist

- [ ] Login as admin user → Should redirect to `/admin` dashboard quickly
- [ ] Navigate to `/admin/orders` → Should load orders without timeout errors
- [ ] Navigate to `/admin/menu` → Should load menus without timeout errors
- [ ] Click between admin tabs → Should not redirect to login
- [ ] Refresh admin page → Should stay on admin page (no redirect loop)
- [ ] Sign out from admin → Should redirect to login cleanly
- [ ] Try to access `/admin` without login → Should redirect to login

## Performance Improvements

- **Faster auth checks**: 3-second timeout vs 5-8 seconds before
- **No redundant calls**: Single auth check per page load
- **Better UX**: Clear loading states, no infinite spinners
- **Reliable navigation**: No more redirect loops or stuck states

## Future Considerations

1. **Session persistence**: Consider adding session storage to reduce auth checks
2. **Optimistic UI**: Show cached data while refreshing in background
3. **Error recovery**: Add retry buttons for failed data fetches
4. **Connection monitoring**: Detect offline state and show appropriate message
