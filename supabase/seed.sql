-- Seed file for production deployment
-- This file contains essential data needed for the application to function

-- Insert subscription plans (essential for app functionality)
INSERT INTO public.subscription_plans (id, name, meals_per_month, price_eur, tokens_per_month, description, is_active) VALUES
('8', '8 Meals Plan', 8, 11900, 8, 'Perfect for couples or light eaters', true),
('16', '16 Meals Plan', 16, 19900, 16, 'Most popular - great for small families', true),
('24', '24 Meals Plan', 24, 27900, 24, 'Ideal for larger families', true),
('28', '28 Meals Plan', 28, 31900, 28, 'Maximum variety and convenience', true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    meals_per_month = EXCLUDED.meals_per_month,
    price_eur = EXCLUDED.price_eur,
    tokens_per_month = EXCLUDED.tokens_per_month,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Insert common ingredients for recipe building
INSERT INTO public.ingredients (name, category, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g, common_allergens, is_vegan, is_vegetarian, is_gluten_free) VALUES
('Salmon', 'protein', 208.00, 25.44, 0.00, 12.35, 0.00, '{"fish"}', false, false, true),
('Chicken Breast', 'protein', 165.00, 31.02, 0.00, 3.57, 0.00, '{}', false, false, true),
('Beef', 'protein', 250.00, 26.00, 0.00, 15.00, 0.00, '{}', false, false, true),
('Tofu', 'protein', 76.00, 8.00, 1.90, 4.80, 0.30, '{"soy"}', true, true, true),
('Quinoa', 'grain', 368.00, 14.12, 64.16, 6.07, 7.00, '{}', true, true, true),
('Brown Rice', 'grain', 370.00, 7.90, 77.20, 2.90, 3.50, '{}', true, true, true),
('Sweet Potato', 'vegetable', 86.00, 1.57, 20.12, 0.05, 3.00, '{}', true, true, true),
('Broccoli', 'vegetable', 34.00, 2.82, 6.64, 0.37, 2.60, '{}', true, true, true),
('Spinach', 'vegetable', 23.00, 2.86, 3.63, 0.39, 2.20, '{}', true, true, true),
('Avocado', 'fruit', 160.00, 2.00, 8.53, 14.66, 6.70, '{}', true, true, true),
('Olive Oil', 'fat', 884.00, 0.00, 0.00, 100.00, 0.00, '{}', true, true, true),
('Coconut Milk', 'dairy_alternative', 230.00, 2.29, 5.54, 23.84, 2.20, '{"coconut"}', true, true, true),
('Greek Yogurt', 'dairy', 59.00, 10.00, 3.60, 0.39, 0.00, '{"milk"}', false, true, true),
('Cheddar Cheese', 'dairy', 403.00, 24.90, 1.28, 33.14, 0.00, '{"milk"}', false, true, true),
('Eggs', 'protein', 155.00, 13.00, 1.10, 11.00, 0.00, '{"eggs"}', false, true, true),
('Almonds', 'nuts', 579.00, 21.15, 21.55, 49.93, 12.50, '{"nuts"}', true, true, true),
('Black Beans', 'legume', 132.00, 8.86, 23.71, 0.54, 8.70, '{}', true, true, true),
('Lemon', 'fruit', 29.00, 1.10, 9.32, 0.30, 2.80, '{}', true, true, true),
('Garlic', 'vegetable', 149.00, 6.36, 33.06, 0.50, 2.10, '{}', true, true, true),
('Onion', 'vegetable', 40.00, 1.10, 9.34, 0.10, 1.70, '{}', true, true, true)
ON CONFLICT (name) DO NOTHING;
