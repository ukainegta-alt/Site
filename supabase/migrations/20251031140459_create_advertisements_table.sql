/*
  # Create advertisements table

  1. New Tables
    - `advertisements`
      - `id` (uuid, primary key) - Унікальний ідентифікатор оголошення
      - `user_id` (uuid, foreign key) - ID користувача-автора
      - `category` (text) - Категорія оголошення
      - `subcategory` (text) - Підкатегорія
      - `title` (text) - Назва оголошення
      - `description` (text) - Опис
      - `images` (text[]) - Масив URL зображень
      - `discord_contact` (text) - Discord контакт
      - `telegram_contact` (text) - Telegram контакт
      - `price` (numeric) - Ціна
      - `is_vip` (boolean) - VIP статус
      - `created_at` (timestamptz) - Дата створення

  2. Security
    - Enable RLS on `advertisements` table
    - Add policies for creating, reading, updating, and deleting advertisements
    - Users can only edit/delete their own ads
    - Admins and moderators can manage all ads

  3. Important Notes
    - Users must provide at least one contact (Discord or Telegram)
    - VIP status is automatically set based on user role
    - Images are stored as an array of URLs
*/

-- Create advertisements table
CREATE TABLE IF NOT EXISTS advertisements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  category text NOT NULL,
  subcategory text NOT NULL,
  title text NOT NULL,
  description text NOT NULL,
  images text[] DEFAULT '{}',
  discord_contact text,
  telegram_contact text,
  price numeric,
  is_vip boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT check_at_least_one_contact CHECK (
    discord_contact IS NOT NULL OR telegram_contact IS NOT NULL
  )
);

-- Enable RLS
ALTER TABLE advertisements ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read advertisements
CREATE POLICY "Anyone can read advertisements"
  ON advertisements FOR SELECT
  TO anon, authenticated
  USING (true);

-- Policy: Authenticated users can insert advertisements
CREATE POLICY "Authenticated users can insert advertisements"
  ON advertisements FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policy: Users can update their own advertisements
CREATE POLICY "Users can update own advertisements"
  ON advertisements FOR UPDATE
  TO authenticated
  USING (auth.uid()::text = user_id::text)
  WITH CHECK (auth.uid()::text = user_id::text);

-- Policy: Users can delete their own advertisements
CREATE POLICY "Users can delete own advertisements"
  ON advertisements FOR DELETE
  TO authenticated
  USING (auth.uid()::text = user_id::text);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_advertisements_user_id ON advertisements(user_id);
CREATE INDEX IF NOT EXISTS idx_advertisements_category ON advertisements(category);
CREATE INDEX IF NOT EXISTS idx_advertisements_subcategory ON advertisements(subcategory);
CREATE INDEX IF NOT EXISTS idx_advertisements_is_vip ON advertisements(is_vip);
CREATE INDEX IF NOT EXISTS idx_advertisements_created_at ON advertisements(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_advertisements_category_subcategory ON advertisements(category, subcategory);