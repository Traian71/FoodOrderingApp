-- Update RLS policies to allow admin users direct access to admin-managed tables
-- This replaces the overly restrictive service_role-only policies

-- Drop ALL existing policies for admin-managed tables to avoid conflicts
-- Ingredients table policies
DROP POLICY IF EXISTS "service_role_full_access" ON public.ingredients;
DROP POLICY IF EXISTS "block_non_service_access" ON public.ingredients;
DROP POLICY IF EXISTS "admin_full_access_ingredients" ON public.ingredients;
DROP POLICY IF EXISTS "service_role_ingredients" ON public.ingredients;
DROP POLICY IF EXISTS "block_non_admin_ingredients" ON public.ingredients;
DROP POLICY IF EXISTS "block_anon_ingredients" ON public.ingredients;
DROP POLICY IF EXISTS "ingredients_select_policy" ON public.ingredients;
DROP POLICY IF EXISTS "ingredients_insert_policy" ON public.ingredients;
DROP POLICY IF EXISTS "ingredients_update_policy" ON public.ingredients;
DROP POLICY IF EXISTS "ingredients_delete_policy" ON public.ingredients;

-- Dishes table policies
DROP POLICY IF EXISTS "service_role_full_access" ON public.dishes;
DROP POLICY IF EXISTS "block_non_service_access" ON public.dishes;
DROP POLICY IF EXISTS "admin_full_access_dishes" ON public.dishes;
DROP POLICY IF EXISTS "service_role_dishes" ON public.dishes;
DROP POLICY IF EXISTS "block_non_admin_dishes" ON public.dishes;
DROP POLICY IF EXISTS "block_anon_dishes" ON public.dishes;
DROP POLICY IF EXISTS "dishes_select_policy" ON public.dishes;
DROP POLICY IF EXISTS "dishes_insert_policy" ON public.dishes;
DROP POLICY IF EXISTS "dishes_update_policy" ON public.dishes;
DROP POLICY IF EXISTS "dishes_delete_policy" ON public.dishes;

-- Dish ingredients table policies
DROP POLICY IF EXISTS "service_role_full_access" ON public.dish_ingredients;
DROP POLICY IF EXISTS "block_non_service_access" ON public.dish_ingredients;
DROP POLICY IF EXISTS "admin_full_access_dish_ingredients" ON public.dish_ingredients;
DROP POLICY IF EXISTS "service_role_dish_ingredients" ON public.dish_ingredients;
DROP POLICY IF EXISTS "block_non_admin_dish_ingredients" ON public.dish_ingredients;
DROP POLICY IF EXISTS "block_anon_dish_ingredients" ON public.dish_ingredients;
DROP POLICY IF EXISTS "dish_ingredients_select_policy" ON public.dish_ingredients;
DROP POLICY IF EXISTS "dish_ingredients_insert_policy" ON public.dish_ingredients;
DROP POLICY IF EXISTS "dish_ingredients_update_policy" ON public.dish_ingredients;
DROP POLICY IF EXISTS "dish_ingredients_delete_policy" ON public.dish_ingredients;

-- Menu weeks table policies
DROP POLICY IF EXISTS "service_role_full_access" ON public.menu_weeks;
DROP POLICY IF EXISTS "block_non_service_access" ON public.menu_weeks;
DROP POLICY IF EXISTS "admin_full_access_menu_weeks" ON public.menu_weeks;
DROP POLICY IF EXISTS "service_role_menu_weeks" ON public.menu_weeks;
DROP POLICY IF EXISTS "block_non_admin_menu_weeks" ON public.menu_weeks;
DROP POLICY IF EXISTS "block_anon_menu_weeks" ON public.menu_weeks;
DROP POLICY IF EXISTS "menu_weeks_select_policy" ON public.menu_weeks;
DROP POLICY IF EXISTS "menu_weeks_insert_policy" ON public.menu_weeks;
DROP POLICY IF EXISTS "menu_weeks_update_policy" ON public.menu_weeks;
DROP POLICY IF EXISTS "menu_weeks_delete_policy" ON public.menu_weeks;

-- Menu items table policies
DROP POLICY IF EXISTS "service_role_full_access" ON public.menu_items;
DROP POLICY IF EXISTS "block_non_service_access" ON public.menu_items;
DROP POLICY IF EXISTS "admin_full_access_menu_items" ON public.menu_items;
DROP POLICY IF EXISTS "service_role_menu_items" ON public.menu_items;
DROP POLICY IF EXISTS "block_non_admin_menu_items" ON public.menu_items;
DROP POLICY IF EXISTS "block_anon_menu_items" ON public.menu_items;
DROP POLICY IF EXISTS "menu_items_select_policy" ON public.menu_items;
DROP POLICY IF EXISTS "menu_items_insert_policy" ON public.menu_items;
DROP POLICY IF EXISTS "menu_items_update_policy" ON public.menu_items;
DROP POLICY IF EXISTS "menu_items_delete_policy" ON public.menu_items;

-- Create new admin-friendly policies for ingredients table
CREATE POLICY "admin_full_access_ingredients" ON public.ingredients
    FOR ALL TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "service_role_ingredients" ON public.ingredients
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Create new admin-friendly policies for dishes table
CREATE POLICY "admin_full_access_dishes" ON public.dishes
    FOR ALL TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "service_role_dishes" ON public.dishes
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Create new admin-friendly policies for dish_ingredients table
CREATE POLICY "admin_full_access_dish_ingredients" ON public.dish_ingredients
    FOR ALL TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "service_role_dish_ingredients" ON public.dish_ingredients
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Create new admin-friendly policies for menu_weeks table
CREATE POLICY "admin_full_access_menu_weeks" ON public.menu_weeks
    FOR ALL TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "service_role_menu_weeks" ON public.menu_weeks
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Create new admin-friendly policies for menu_items table
CREATE POLICY "admin_full_access_menu_items" ON public.menu_items
    FOR ALL TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users 
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "service_role_menu_items" ON public.menu_items
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- We don't need separate blocking policies since our admin policies already handle this
-- The admin policies will allow admins access and implicitly block non-admins
