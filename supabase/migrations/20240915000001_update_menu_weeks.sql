-- Update menu weeks to current dates for testing
-- This migration updates the sample menu weeks to current dates

-- Update existing menu weeks to current dates
UPDATE public.menu_weeks 
SET 
  year = 2025,
  start_date = '2025-09-15',
  end_date = '2025-09-21',
  delivery_start_date = '2025-09-12',
  delivery_end_date = '2025-09-15',
  order_cutoff_date = '2025-09-10 23:59:59+00'
WHERE week_number = 38 AND year = 2024;

UPDATE public.menu_weeks 
SET 
  year = 2025,
  start_date = '2025-09-22',
  end_date = '2025-09-28',
  delivery_start_date = '2025-09-19',
  delivery_end_date = '2025-09-22',
  order_cutoff_date = '2025-09-17 23:59:59+00'
WHERE week_number = 39 AND year = 2024;

UPDATE public.menu_weeks 
SET 
  year = 2025,
  start_date = '2025-09-29',
  end_date = '2025-10-05',
  delivery_start_date = '2025-09-26',
  delivery_end_date = '2025-09-29',
  order_cutoff_date = '2025-09-24 23:59:59+00',
  is_active = true
WHERE week_number = 40 AND year = 2024;

-- Update delivery schedules to match new dates
UPDATE public.delivery_schedules 
SET scheduled_date = '2025-09-12'
WHERE delivery_group = '1' AND scheduled_date = '2024-09-13';

UPDATE public.delivery_schedules 
SET scheduled_date = '2025-09-13'
WHERE delivery_group = '2' AND scheduled_date = '2024-09-14';

UPDATE public.delivery_schedules 
SET scheduled_date = '2025-09-14'
WHERE delivery_group = '3' AND scheduled_date = '2024-09-15';

UPDATE public.delivery_schedules 
SET scheduled_date = '2025-09-15'
WHERE delivery_group = '4' AND scheduled_date = '2024-09-16';
