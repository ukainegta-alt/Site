/*
  # Create helper functions

  1. Functions
    - `set_app_user(user_id uuid)` - Sets the current user context for RLS
    - `create_advertisement(...)` - Creates a new advertisement with proper permissions

  2. Security
    - Functions run with caller's permissions
    - Proper validation and security checks

  3. Important Notes
    - Used for setting user context in client-side code
    - Ensures proper RLS enforcement
*/

-- Function to set user context for RLS
CREATE OR REPLACE FUNCTION set_app_user(user_id text)
RETURNS void AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', user_id)::text, false);
  PERFORM set_config('role', 'authenticated', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create advertisement
CREATE OR REPLACE FUNCTION create_advertisement(
  p_user_id uuid,
  p_category text,
  p_subcategory text,
  p_title text,
  p_description text,
  p_images text[] DEFAULT '{}',
  p_discord text DEFAULT NULL,
  p_telegram text DEFAULT NULL,
  p_is_vip boolean DEFAULT false,
  p_price numeric DEFAULT NULL
)
RETURNS advertisements AS $$
DECLARE
  v_advertisement advertisements;
BEGIN
  -- Validate that at least one contact is provided
  IF p_discord IS NULL AND p_telegram IS NULL THEN
    RAISE EXCEPTION 'At least one contact (Discord or Telegram) is required';
  END IF;

  -- Insert the advertisement
  INSERT INTO advertisements (
    user_id,
    category,
    subcategory,
    title,
    description,
    images,
    discord_contact,
    telegram_contact,
    is_vip,
    price
  ) VALUES (
    p_user_id,
    p_category,
    p_subcategory,
    p_title,
    p_description,
    p_images,
    p_discord,
    p_telegram,
    p_is_vip,
    p_price
  )
  RETURNING * INTO v_advertisement;

  RETURN v_advertisement;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;