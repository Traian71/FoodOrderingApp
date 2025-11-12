-- Migration: Add group_assigned column to users table
-- This column tracks whether a user has been assigned to a delivery group by an admin

-- Add group_assigned column to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS group_assigned BOOLEAN DEFAULT false NOT NULL;

-- Create index for faster lookups (used in admin queries)
CREATE INDEX IF NOT EXISTS idx_users_group_assigned ON public.users(group_assigned);

-- Update existing users who have a delivery_group set to mark them as assigned
UPDATE public.users 
SET group_assigned = true 
WHERE delivery_group IS NOT NULL AND group_assigned = false;

-- Add comment for documentation
COMMENT ON COLUMN public.users.group_assigned IS 'Indicates whether the user has been manually assigned to a delivery group by an admin. False means the user is pending group assignment.';
