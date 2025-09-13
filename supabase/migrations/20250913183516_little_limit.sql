/*
  # Create messaging system

  1. New Tables
    - `conversations`
      - `id` (uuid, primary key)
      - `user1_id` (uuid, references auth.users)
      - `user2_id` (uuid, references auth.users)
      - `advertisement_id` (uuid, references advertisements, optional)
      - `last_message_id` (uuid, references messages, optional)
      - `user1_unread_count` (integer, default 0)
      - `user2_unread_count` (integer, default 0)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `messages`
      - `id` (uuid, primary key)
      - `sender_id` (uuid, references auth.users)
      - `receiver_id` (uuid, references auth.users)
      - `conversation_id` (uuid, references conversations)
      - `advertisement_id` (uuid, references advertisements, optional)
      - `content` (text)
      - `is_read` (boolean, default false)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add policies for users to manage their own conversations and messages
    
  3. Functions
    - Function to automatically create/find conversations
    - Trigger to update conversation metadata
*/

-- Create conversations table
CREATE TABLE IF NOT EXISTS conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user2_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  advertisement_id uuid REFERENCES advertisements(id) ON DELETE CASCADE,
  last_message_id uuid,
  user1_unread_count integer DEFAULT 0,
  user2_unread_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user1_id, user2_id, advertisement_id)
);

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  conversation_id uuid REFERENCES conversations(id) ON DELETE CASCADE,
  advertisement_id uuid REFERENCES advertisements(id) ON DELETE CASCADE,
  content text NOT NULL,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Add foreign key for last_message_id after messages table is created
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'conversations_last_message_id_fkey'
  ) THEN
    ALTER TABLE conversations 
    ADD CONSTRAINT conversations_last_message_id_fkey 
    FOREIGN KEY (last_message_id) REFERENCES messages(id);
  END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_conversations_user1_id ON conversations(user1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_user2_id ON conversations(user2_id);
CREATE INDEX IF NOT EXISTS idx_conversations_advertisement_id ON conversations(advertisement_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON conversations(updated_at);

CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

-- Enable RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for conversations
CREATE POLICY "users_can_view_their_conversations"
  ON conversations FOR SELECT
  TO authenticated
  USING (uid() = user1_id OR uid() = user2_id);

CREATE POLICY "users_can_insert_conversations"
  ON conversations FOR INSERT
  TO authenticated
  WITH CHECK (uid() = user1_id OR uid() = user2_id);

CREATE POLICY "users_can_update_their_conversations"
  ON conversations FOR UPDATE
  TO authenticated
  USING (uid() = user1_id OR uid() = user2_id);

CREATE POLICY "users_can_delete_their_conversations"
  ON conversations FOR DELETE
  TO authenticated
  USING (uid() = user1_id OR uid() = user2_id);

-- RLS Policies for messages
CREATE POLICY "users_can_view_their_messages"
  ON messages FOR SELECT
  TO authenticated
  USING (uid() = sender_id OR uid() = receiver_id);

CREATE POLICY "users_can_insert_their_messages"
  ON messages FOR INSERT
  TO authenticated
  WITH CHECK (uid() = sender_id);

CREATE POLICY "users_can_update_their_messages"
  ON messages FOR UPDATE
  TO authenticated
  USING (uid() = receiver_id);

CREATE POLICY "users_can_delete_their_messages"
  ON messages FOR DELETE
  TO authenticated
  USING (uid() = sender_id OR uid() = receiver_id);

-- Function to automatically set conversation_id for new messages
CREATE OR REPLACE FUNCTION set_message_conversation()
RETURNS TRIGGER AS $$
DECLARE
  conv_id uuid;
  user1 uuid;
  user2 uuid;
BEGIN
  -- Determine user1 and user2 (smaller uuid first for consistency)
  IF NEW.sender_id < NEW.receiver_id THEN
    user1 := NEW.sender_id;
    user2 := NEW.receiver_id;
  ELSE
    user1 := NEW.receiver_id;
    user2 := NEW.sender_id;
  END IF;

  -- Find or create conversation
  SELECT id INTO conv_id
  FROM conversations
  WHERE user1_id = user1 
    AND user2_id = user2 
    AND (advertisement_id = NEW.advertisement_id OR (advertisement_id IS NULL AND NEW.advertisement_id IS NULL));

  IF conv_id IS NULL THEN
    INSERT INTO conversations (user1_id, user2_id, advertisement_id)
    VALUES (user1, user2, NEW.advertisement_id)
    RETURNING id INTO conv_id;
  END IF;

  NEW.conversation_id := conv_id;
  
  -- Update conversation metadata
  UPDATE conversations 
  SET 
    last_message_id = NEW.id,
    updated_at = now(),
    user1_unread_count = CASE 
      WHEN user1 = NEW.receiver_id THEN user1_unread_count + 1 
      ELSE user1_unread_count 
    END,
    user2_unread_count = CASE 
      WHEN user2 = NEW.receiver_id THEN user2_unread_count + 1 
      ELSE user2_unread_count 
    END
  WHERE id = conv_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS set_message_conversation_trigger ON messages;
CREATE TRIGGER set_message_conversation_trigger
  BEFORE INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION set_message_conversation();