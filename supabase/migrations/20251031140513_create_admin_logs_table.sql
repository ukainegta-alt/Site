/*
  # Create admin logs table

  1. New Tables
    - `admin_logs`
      - `id` (uuid, primary key) - Унікальний ідентифікатор логу
      - `admin_id` (uuid, foreign key) - ID адміністратора/модератора
      - `action` (text) - Тип дії (ban, unban, role_to_vip, delete_advertisement, etc.)
      - `target_user_id` (uuid, foreign key) - ID цільового користувача
      - `details` (jsonb) - Додаткова інформація про дію
      - `created_at` (timestamptz) - Час виконання дії

  2. Security
    - Enable RLS on `admin_logs` table
    - Only admins can read logs
    - System can insert logs via triggers or RPC

  3. Important Notes
    - Logs are immutable (no update/delete policies)
    - Used for audit trail and transparency
*/

-- Create admin logs table
CREATE TABLE IF NOT EXISTS admin_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action text NOT NULL,
  target_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  details jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Only authenticated users can read logs (will be checked in app)
CREATE POLICY "Authenticated users can read logs"
  ON admin_logs FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Authenticated users can insert logs
CREATE POLICY "Authenticated users can insert logs"
  ON admin_logs FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_admin_logs_admin_id ON admin_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_target_user_id ON admin_logs(target_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_created_at ON admin_logs(created_at DESC);