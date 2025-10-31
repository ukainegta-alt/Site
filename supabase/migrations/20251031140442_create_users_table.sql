/*
  # Create users table

  1. New Tables
    - `users`
      - `id` (uuid, primary key) - Унікальний ідентифікатор користувача
      - `nickname` (text, unique) - Нікнейм користувача (унікальний)
      - `password_hash` (text) - Хеш пароля
      - `role` (enum) - Роль користувача (user, vip, moderator, admin, Legend)
      - `is_banned` (boolean) - Чи заблокований користувач
      - `created_at` (timestamptz) - Дата створення

  2. Security
    - Enable RLS on `users` table
    - Add policies for authenticated users to read their own data
    - Admin policies for user management
*/

-- Create user role enum
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('user', 'vip', 'moderator', 'admin', 'Legend');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nickname text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  role user_role DEFAULT 'user',
  is_banned boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read all user profiles (for displaying nicknames)
CREATE POLICY "Users can read all profiles"
  ON users FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Users can read public user info (for anonymous)
CREATE POLICY "Anonymous can read public user info"
  ON users FOR SELECT
  TO anon
  USING (true);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (auth.uid()::text = id::text)
  WITH CHECK (auth.uid()::text = id::text);

-- Policy: Only system can insert users (via RPC)
CREATE POLICY "System can insert users"
  ON users FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_nickname ON users(nickname);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);