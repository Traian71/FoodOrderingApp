# Simon's Freezer Meals - Supabase Database Setup

This directory contains the complete Supabase database schema and migrations for the Simon's Freezer Meals food ordering application.

## Architecture Overview

The database is designed for a **FastAPI backend architecture** where:
- Frontend (Next.js) communicates only with FastAPI backend
- FastAPI backend handles all database operations
- Row Level Security (RLS) prevents direct frontend access
- Additional security through backend service authentication

## Database Schema

### Core Tables

#### Users & Authentication
- `users` - User profiles (extends Supabase auth.users)
- `user_addresses` - Delivery addresses with delivery group assignment
- `user_dietary_preferences` - Dietary restrictions and preferences
- `user_allergens` - Allergen information and severity

#### Subscription System
- `subscription_plans` - Available plans (8, 16, 24, 28 meals)
- `user_subscriptions` - User subscription status and billing
- `billing_history` - Payment records and invoices

#### Token System
- `token_wallets` - User token balances and limits
- `token_transactions` - Complete transaction history with rollover logic

#### Menu & Dishes
- `ingredients` - Ingredient database with nutritional info
- `dishes` - Recipe database with dietary tags
- `dish_ingredients` - Recipe compositions
- `menu_weeks` - Weekly menu cycles
- `menu_items` - Dishes available in specific weeks

#### Orders & Delivery
- `orders` - Order management with status tracking
- `order_items` - Individual meal selections
- `delivery_schedules` - Zone-based delivery planning

## Migration Files

1. **`20240901000001_initial_schema.sql`**
   - Creates all tables, indexes, and constraints
   - Defines custom types and enums
   - Inserts default subscription plans

2. **`20240901000002_row_level_security.sql`**
   - Enables RLS on all tables
   - Creates backend-only access policies
   - Sets up authentication functions

3. **`20240901000003_triggers_and_functions.sql`**
   - Automated token management triggers
   - Business logic functions
   - Data consistency triggers

4. **`20240901000004_sample_data.sql`**
   - Sample ingredients and dishes
   - Test menu weeks
   - Development data

## Key Features

### Token Management
- Automatic monthly deposits based on subscription
- Rollover logic (max = plan limit)
- Token deduction on order confirmation
- Refunds on order cancellation

### Subscription Logic
- 4 subscription tiers with different token allocations
- Automatic billing cycle management
- Pause/resume functionality
- Plan change handling

### Delivery System
- Zone-based delivery (Groups 1-4)
- Automatic postal code to delivery group mapping
- Delivery scheduling and tracking

### Security
- Backend service role for FastAPI access
- RLS policies prevent direct frontend access
- Authenticated read access for public menu data
- Secure token transaction processing

## Setup Instructions

### 1. Initialize Supabase Project
```bash
# Install Supabase CLI
npm install -g supabase

# Initialize project
supabase init

# Start local development
supabase start
```

### 2. Run Migrations
```bash
# Apply all migrations
supabase db reset

# Or apply individually
supabase db push
```

### 3. Configure Backend Service Role

In your Supabase dashboard or via SQL:

```sql
-- Create backend service role
CREATE ROLE backend_service WITH LOGIN PASSWORD 'your-secure-backend-password';
GRANT USAGE ON SCHEMA public TO backend_service;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO backend_service;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO backend_service;
```

### 4. Environment Variables

For your FastAPI backend:

```env
SUPABASE_URL=your-supabase-url
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_BACKEND_TOKEN=your-backend-auth-token
DATABASE_URL=postgresql://backend_service:password@localhost:54322/postgres
```

## Usage Examples

### Token Operations
```sql
-- Check user token balance
SELECT get_user_token_balance('user-uuid');

-- Process monthly deposits (run via cron)
SELECT process_monthly_token_deposits();

-- Check if user can place order
SELECT can_user_order('user-uuid', 3);
```

### Menu Queries
```sql
-- Get filtered menu for user
SELECT * FROM get_filtered_menu('menu-week-uuid', 'user-uuid');

-- Get public menu (no user filtering)
SELECT * FROM public_menu WHERE menu_week_id = 'menu-week-uuid';
```

### Order Management
```sql
-- Orders automatically validate token balance
-- Tokens are deducted when status changes to 'confirmed'
-- Refunds are processed when status changes to 'cancelled'
```

## Scheduled Tasks

Set up these cron jobs for your FastAPI backend:

```python
# Daily: Process monthly token deposits
# SELECT process_monthly_token_deposits();

# Weekly: Clean up expired menu weeks  
# SELECT cleanup_expired_menu_weeks();
```

## Development Notes

- All monetary amounts stored in cents (EUR)
- Timestamps use UTC with timezone awareness
- Postal codes validated for Danish format (4 digits)
- Delivery groups automatically assigned by postal code
- Token transactions are immutable (audit trail)

## Production Considerations

1. **Security**
   - Use strong passwords for backend service role
   - Implement proper JWT verification in backend
   - Set up SSL/TLS for all connections

2. **Performance**
   - Monitor query performance with indexes
   - Consider read replicas for heavy read operations
   - Implement caching for menu data

3. **Backup**
   - Set up automated database backups
   - Test restore procedures
   - Monitor disk usage

4. **Monitoring**
   - Set up alerts for failed token transactions
   - Monitor subscription billing failures
   - Track order processing times

## API Integration

The FastAPI backend should implement endpoints that:
- Authenticate using the backend service role
- Validate business rules before database operations
- Handle token transactions atomically
- Provide filtered data based on user permissions

Example FastAPI service structure:
```python
class SupabaseService:
    def __init__(self):
        self.client = create_client(url, service_role_key)
    
    async def create_order(self, user_id, order_data):
        # Validate token balance
        # Create order with automatic token deduction
        # Return order confirmation
```
