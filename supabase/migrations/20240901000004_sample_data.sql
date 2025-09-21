-- Sample data for development and testing
-- This migration populates the database with realistic sample data

-- Insert sample ingredients
INSERT INTO public.ingredients (id, name, category, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g, common_allergens, is_vegan, is_vegetarian, is_gluten_free) VALUES
(uuid_generate_v4(), 'Salmon Fillet', 'protein', 208.00, 25.44, 0.00, 12.35, 0.00, '{"fish"}', false, false, true),
(uuid_generate_v4(), 'Chicken Breast', 'protein', 165.00, 31.02, 0.00, 3.57, 0.00, '{}', false, false, true),
(uuid_generate_v4(), 'Quinoa', 'grain', 368.00, 14.12, 64.16, 6.07, 7.00, '{}', true, true, true),
(uuid_generate_v4(), 'Butternut Squash', 'vegetable', 45.00, 1.00, 11.69, 0.10, 2.00, '{}', true, true, true),
(uuid_generate_v4(), 'Coconut Milk', 'dairy_alternative', 230.00, 2.29, 5.54, 23.84, 2.20, '{"coconut"}', true, true, true),
(uuid_generate_v4(), 'Pearl Onions', 'vegetable', 42.00, 0.90, 9.80, 0.10, 1.70, '{}', true, true, true),
(uuid_generate_v4(), 'Mushrooms', 'vegetable', 22.00, 3.09, 3.26, 0.34, 1.00, '{}', true, true, true),
(uuid_generate_v4(), 'Jasmine Rice', 'grain', 365.00, 7.13, 79.95, 0.66, 1.40, '{}', true, true, true),
(uuid_generate_v4(), 'Chickpeas', 'legume', 164.00, 8.86, 27.42, 2.59, 7.60, '{}', true, true, true),
(uuid_generate_v4(), 'Tahini', 'condiment', 595.00, 17.00, 21.00, 53.76, 9.30, '{"sesame"}', true, true, true),
(uuid_generate_v4(), 'Cucumber', 'vegetable', 16.00, 0.65, 4.00, 0.11, 0.50, '{}', true, true, true),
(uuid_generate_v4(), 'Seaweed', 'vegetable', 45.00, 3.03, 9.57, 0.56, 0.30, '{}', true, true, true),
(uuid_generate_v4(), 'Sushi Rice', 'grain', 356.00, 6.50, 77.90, 0.58, 1.40, '{}', true, true, true),
(uuid_generate_v4(), 'Unagi Sauce', 'condiment', 180.00, 2.00, 40.00, 1.00, 0.00, '{"soy", "wheat"}', false, true, false),
(uuid_generate_v4(), 'Green Curry Paste', 'condiment', 65.00, 2.50, 8.00, 2.00, 3.00, '{}', true, true, true),
(uuid_generate_v4(), 'Red Wine', 'alcohol', 85.00, 0.07, 2.61, 0.00, 0.00, '{"sulfites"}', true, true, true),
(uuid_generate_v4(), 'Ginger', 'spice', 80.00, 1.82, 17.77, 0.75, 2.00, '{}', true, true, true),
(uuid_generate_v4(), 'Maple Syrup', 'sweetener', 260.00, 0.04, 67.04, 0.06, 0.00, '{}', true, true, true);

-- Insert sample menu weeks
INSERT INTO public.menu_weeks (id, week_number, year, start_date, end_date, delivery_start_date, delivery_end_date, order_cutoff_date, is_active) VALUES
(uuid_generate_v4(), 38, 2024, '2024-09-16', '2024-09-22', '2024-09-13', '2024-09-16', '2024-09-11 23:59:59+00', true),
(uuid_generate_v4(), 39, 2024, '2024-09-23', '2024-09-29', '2024-09-20', '2024-09-23', '2024-09-18 23:59:59+00', true),
(uuid_generate_v4(), 40, 2024, '2024-09-30', '2024-10-06', '2024-09-27', '2024-09-30', '2024-09-25 23:59:59+00', false);

-- Get ingredient IDs for dish creation
DO $$
DECLARE
    salmon_id UUID;
    chicken_id UUID;
    quinoa_id UUID;
    squash_id UUID;
    coconut_milk_id UUID;
    pearl_onions_id UUID;
    mushrooms_id UUID;
    jasmine_rice_id UUID;
    chickpeas_id UUID;
    tahini_id UUID;
    cucumber_id UUID;
    seaweed_id UUID;
    sushi_rice_id UUID;
    unagi_sauce_id UUID;
    curry_paste_id UUID;
    red_wine_id UUID;
    ginger_id UUID;
    maple_syrup_id UUID;
    
    dish1_id UUID := uuid_generate_v4();
    dish2_id UUID := uuid_generate_v4();
    dish3_id UUID := uuid_generate_v4();
    dish4_id UUID := uuid_generate_v4();
    dish5_id UUID := uuid_generate_v4();
    
    menu_week_38_id UUID;
BEGIN
    -- Get ingredient IDs
    SELECT id INTO salmon_id FROM public.ingredients WHERE name = 'Salmon Fillet';
    SELECT id INTO chicken_id FROM public.ingredients WHERE name = 'Chicken Breast';
    SELECT id INTO quinoa_id FROM public.ingredients WHERE name = 'Quinoa';
    SELECT id INTO squash_id FROM public.ingredients WHERE name = 'Butternut Squash';
    SELECT id INTO coconut_milk_id FROM public.ingredients WHERE name = 'Coconut Milk';
    SELECT id INTO pearl_onions_id FROM public.ingredients WHERE name = 'Pearl Onions';
    SELECT id INTO mushrooms_id FROM public.ingredients WHERE name = 'Mushrooms';
    SELECT id INTO jasmine_rice_id FROM public.ingredients WHERE name = 'Jasmine Rice';
    SELECT id INTO chickpeas_id FROM public.ingredients WHERE name = 'Chickpeas';
    SELECT id INTO tahini_id FROM public.ingredients WHERE name = 'Tahini';
    SELECT id INTO cucumber_id FROM public.ingredients WHERE name = 'Cucumber';
    SELECT id INTO seaweed_id FROM public.ingredients WHERE name = 'Seaweed';
    SELECT id INTO sushi_rice_id FROM public.ingredients WHERE name = 'Sushi Rice';
    SELECT id INTO unagi_sauce_id FROM public.ingredients WHERE name = 'Unagi Sauce';
    SELECT id INTO curry_paste_id FROM public.ingredients WHERE name = 'Green Curry Paste';
    SELECT id INTO red_wine_id FROM public.ingredients WHERE name = 'Red Wine';
    SELECT id INTO ginger_id FROM public.ingredients WHERE name = 'Ginger';
    SELECT id INTO maple_syrup_id FROM public.ingredients WHERE name = 'Maple Syrup';
    
    SELECT id INTO menu_week_38_id FROM public.menu_weeks WHERE week_number = 38 AND year = 2024;

    -- Insert sample dishes
    INSERT INTO public.dishes (id, name, description, preparation_instructions, prep_time_minutes, difficulty, dietary_tags, allergens, token_cost, is_active) VALUES
    (dish1_id, 'Salmon Unagi', 'This dish takes your mind to Japan, with fried salmon brushed with rich Unagi sauce, sushi rice and cucumber and seaweed salad.', 'Cook sushi rice according to package instructions. Pan-fry salmon until golden. Brush with unagi sauce. Prepare cucumber and seaweed salad. Serve together.', 40, 'medium', '{"pescatarian"}', '{"fish", "wheat", "soy", "sesame", "egg", "mustard"}', 2, true),
    (dish2_id, 'Chicken with Pearl Onions', 'We have prepared this French classic to make this French dish simple. You will get wine base, which you can pearl onions, mushrooms and chicken is done.', 'Sear chicken breast until golden. Add pearl onions and mushrooms. Deglaze with red wine. Simmer until chicken is cooked through and sauce reduces.', 35, 'medium', '{"meat"}', '{"milk", "lactose"}', 2, true),
    (dish3_id, 'Mediterranean Quinoa Bowl', 'A vibrant bowl filled with roasted vegetables, quinoa, chickpeas, and our signature tahini dressing.', 'Cook quinoa until fluffy. Roast vegetables until tender. Prepare tahini dressing. Combine all ingredients in a bowl.', 25, 'easy', '{"vegan", "vegetarian"}', '{"sesame", "nuts"}', 1, true),
    (dish4_id, 'Autumn Harvest Soup', 'Warming butternut squash soup with coconut milk, ginger, and a touch of maple syrup.', 'Roast butternut squash until tender. Blend with coconut milk, ginger, and maple syrup. Season to taste. Heat through before serving.', 20, 'easy', '{"vegan", "vegetarian"}', '{}', 1, true),
    (dish5_id, 'Thai Green Curry', 'Aromatic green curry with vegetables and jasmine rice, bursting with authentic Thai flavors.', 'Cook jasmine rice. Heat curry paste in pan. Add coconut milk and vegetables. Simmer until vegetables are tender. Serve over rice.', 30, 'medium', '{"vegan", "vegetarian"}', '{"coconut"}', 2, true);

    -- Insert dish ingredients
    -- Salmon Unagi
    INSERT INTO public.dish_ingredients (dish_id, ingredient_id, quantity, unit, preparation_note) VALUES
    (dish1_id, salmon_id, 150, 'g', 'skin-on fillet'),
    (dish1_id, sushi_rice_id, 80, 'g', 'uncooked'),
    (dish1_id, cucumber_id, 100, 'g', 'julienned'),
    (dish1_id, seaweed_id, 10, 'g', 'dried'),
    (dish1_id, unagi_sauce_id, 30, 'ml', 'for brushing');

    -- Chicken with Pearl Onions
    INSERT INTO public.dish_ingredients (dish_id, ingredient_id, quantity, unit, preparation_note) VALUES
    (dish2_id, chicken_id, 180, 'g', 'boneless breast'),
    (dish2_id, pearl_onions_id, 120, 'g', 'peeled'),
    (dish2_id, mushrooms_id, 100, 'g', 'quartered'),
    (dish2_id, red_wine_id, 100, 'ml', 'for deglazing');

    -- Mediterranean Quinoa Bowl
    INSERT INTO public.dish_ingredients (dish_id, ingredient_id, quantity, unit, preparation_note) VALUES
    (dish3_id, quinoa_id, 80, 'g', 'uncooked'),
    (dish3_id, chickpeas_id, 100, 'g', 'cooked'),
    (dish3_id, cucumber_id, 80, 'g', 'diced'),
    (dish3_id, tahini_id, 20, 'g', 'for dressing');

    -- Autumn Harvest Soup
    INSERT INTO public.dish_ingredients (dish_id, ingredient_id, quantity, unit, preparation_note) VALUES
    (dish4_id, squash_id, 300, 'g', 'peeled and cubed'),
    (dish4_id, coconut_milk_id, 200, 'ml', 'full-fat'),
    (dish4_id, ginger_id, 10, 'g', 'fresh, grated'),
    (dish4_id, maple_syrup_id, 15, 'ml', 'pure');

    -- Thai Green Curry
    INSERT INTO public.dish_ingredients (dish_id, ingredient_id, quantity, unit, preparation_note) VALUES
    (dish5_id, jasmine_rice_id, 80, 'g', 'uncooked'),
    (dish5_id, coconut_milk_id, 250, 'ml', 'full-fat'),
    (dish5_id, curry_paste_id, 25, 'g', 'green curry'),
    (dish5_id, squash_id, 150, 'g', 'cubed');

    -- Insert menu items for week 38
    INSERT INTO public.menu_items (menu_week_id, dish_id, protein_options, is_featured, display_order) VALUES
    (menu_week_38_id, dish1_id, '{"salmon", "tofu"}', true, 1),
    (menu_week_38_id, dish2_id, '{"chicken", "mushroom"}', false, 2),
    (menu_week_38_id, dish3_id, '{}', false, 3),
    (menu_week_38_id, dish4_id, '{}', false, 4),
    (menu_week_38_id, dish5_id, '{}', false, 5);
END $$;

-- Insert sample delivery schedules
DO $$
DECLARE
    menu_week_38_id UUID;
BEGIN
    SELECT id INTO menu_week_38_id FROM public.menu_weeks WHERE week_number = 38 AND year = 2024;
    
    INSERT INTO public.delivery_schedules (delivery_group, menu_week_id, scheduled_date, time_window_start, time_window_end, driver_notes) VALUES
    ('1', menu_week_38_id, '2024-09-13', '10:00', '14:00', 'Copenhagen area - morning delivery'),
    ('2', menu_week_38_id, '2024-09-14', '10:00', '14:00', 'Aarhus area - morning delivery'),
    ('3', menu_week_38_id, '2024-09-15', '10:00', '14:00', 'Odense area - morning delivery'),
    ('4', menu_week_38_id, '2024-09-16', '10:00', '14:00', 'Other areas - morning delivery');
END $$;
