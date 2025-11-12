-- Add image_url, suggested_sides, and suggested_toppings to dishes table
-- Also create storage bucket for dish images

-- Add new columns to dishes table
ALTER TABLE dishes
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS suggested_sides TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS suggested_toppings TEXT[] DEFAULT '{}';

-- Create storage bucket for dish images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'dish-images',
  'dish-images',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for dish-images bucket
-- Allow authenticated users to upload images
CREATE POLICY "Authenticated users can upload dish images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'dish-images');

-- Allow public read access to dish images
CREATE POLICY "Public read access to dish images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'dish-images');

-- Allow authenticated users to update their uploaded images
CREATE POLICY "Authenticated users can update dish images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'dish-images')
WITH CHECK (bucket_id = 'dish-images');

-- Allow authenticated users to delete dish images
CREATE POLICY "Authenticated users can delete dish images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'dish-images');

-- Add comment to explain the new columns
COMMENT ON COLUMN dishes.image_url IS 'URL to the dish image stored in Supabase Storage';
COMMENT ON COLUMN dishes.suggested_sides IS 'Array of suggested side dishes (e.g., ["Rice", "Salad", "Bread"])';
COMMENT ON COLUMN dishes.suggested_toppings IS 'Array of suggested toppings (e.g., ["Parmesan", "Fresh Herbs", "Olive Oil"])';
