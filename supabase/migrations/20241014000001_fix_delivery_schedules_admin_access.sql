-- Fix delivery_schedules RLS to allow admin users to insert/update/delete schedules
-- Migration: 20241014000001_fix_delivery_schedules_admin_access.sql

-- Add policy for admin users to manage delivery schedules
CREATE POLICY "admin_full_access_delivery_schedules" ON public.delivery_schedules
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

-- Keep the existing service_role policy for full access
-- (Already exists from previous migrations, no need to recreate)
