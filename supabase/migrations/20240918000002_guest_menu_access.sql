-- Allow guest users (anonymous) to read menu data
-- This migration adds read-only access for anonymous users to menu tables

-- Allow anonymous users to read menu_months
CREATE POLICY "allow_anon_read_menu_months" ON public.menu_months
    FOR SELECT TO anon USING (true);

-- Allow anonymous users to read menu_items
CREATE POLICY "allow_anon_read_menu_items" ON public.menu_items
    FOR SELECT TO anon USING (true);
    
-- Allow anonymous users to read dishes
CREATE POLICY "allow_anon_read_dishes" ON public.dishes
    FOR SELECT TO anon USING (true);

-- Allow anonymous users to read dish_ingredients
CREATE POLICY "allow_anon_read_dish_ingredients" ON public.dish_ingredients
    FOR SELECT TO anon USING (true);

-- Allow anonymous users to read ingredients
CREATE POLICY "allow_anon_read_ingredients" ON public.ingredients
    FOR SELECT TO anon USING (true);
