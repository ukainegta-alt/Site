import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Send, MessageCircle, User } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';
import { supabase } from '@/integrations/supabase/client';
import { toast } from '@/components/ui/sonner';
import { useAuth } from '@/contexts/AuthContext';

interface Message {
  id: string;
  sender_id: string;
  receiver_id: string;
  content: string;
  created_at: string;
  is_read: boolean;
}

interface Conversation {
  id: string;
  user1_id: string;
  user2_id: string;
  advertisement_id?: string;
  last_message_id?: string;
  user1_unread_count: number;
  user2_unread_count: number;
  updated_at: string;
  other_user?: {
    id: string;
    nickname: string;
    role: string;
  };
  advertisement?: {
    title: string;
  };
}

interface MessagingModalProps {
  isOpen: boolean;
  onClose: () => void;
  recipientId?: string;
  advertisementId?: string;
}

const MessagingModal: React.FC<MessagingModalProps> = ({ 
  isOpen, 
  onClose, 
  recipientId, 
  advertisementId 
}) => {
  const { user } = useAuth();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selectedConversation, setSelectedConversation] = useState<string | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (isOpen && user) {
      fetchConversations();
      
      // If recipientId is provided, start a conversation
      if (recipientId) {
        startConversation(recipientId, advertisementId);
      }
    }
  }, [isOpen, user, recipientId, advertisementId]);

  useEffect(() => {
    if (selectedConversation) {
      fetchMessages(selectedConversation);
      markMessagesAsRead(selectedConversation);
    }
  }, [selectedConversation]);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const fetchConversations = async () => {
    if (!user) return;

    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('conversations')
        .select(`
          *,
          advertisements (title)
        `)
        .or(`user1_id.eq.${user.id},user2_id.eq.${user.id}`)
        .order('updated_at', { ascending: false });

      if (error) throw error;

      // Fetch other user details for each conversation
      const conversationsWithUsers = await Promise.all(
        (data || []).map(async (conv) => {
          const otherUserId = conv.user1_id === user.id ? conv.user2_id : conv.user1_id;
          
          const { data: userData } = await supabase
            .from('users')
            .select('id, nickname, role')
            .eq('id', otherUserId)
            .single();

          return {
            ...conv,
            other_user: userData,
            advertisement: conv.advertisements
          };
        })
      );

      setConversations(conversationsWithUsers);
    } catch (error: any) {
      toast.error('Помилка завантаження розмов: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const startConversation = async (recipientId: string, advertisementId?: string) => {
    if (!user) return;

    try {
      // Check if conversation already exists
      const existingConv = conversations.find(conv => 
        (conv.user1_id === user.id && conv.user2_id === recipientId) ||
        (conv.user2_id === user.id && conv.user1_id === recipientId)
      );

      if (existingConv) {
        setSelectedConversation(existingConv.id);
        return;
      }

      // Create new conversation by sending a message
      const { data, error } = await supabase
        .from('messages')
        .insert([{
          sender_id: user.id,
          receiver_id: recipientId,
          advertisement_id: advertisementId,
          content: 'Привіт! Мене цікавить ваше оголошення.'
        }])
        .select()
        .single();

      if (error) throw error;

      // Refresh conversations
      await fetchConversations();
      
      // Select the new conversation
      if (data.conversation_id) {
        setSelectedConversation(data.conversation_id);
      }
    } catch (error: any) {
      toast.error('Помилка створення розмови: ' + error.message);
    }
  };

  const fetchMessages = async (conversationId: string) => {
    try {
      const { data, error } = await supabase
        .from('messages')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setMessages(data || []);
    } catch (error: any) {
      toast.error('Помилка завантаження повідомлень: ' + error.message);
    }
  };

  const markMessagesAsRead = async (conversationId: string) => {
    if (!user) return;

    try {
      await supabase
        .from('messages')
        .update({ is_read: true })
        .eq('conversation_id', conversationId)
        .eq('receiver_id', user.id)
        .eq('is_read', false);

      // Update conversation unread count
      const conversation = conversations.find(c => c.id === conversationId);
      if (conversation) {
        const isUser1 = conversation.user1_id === user.id;
        await supabase
          .from('conversations')
          .update({
            [isUser1 ? 'user1_unread_count' : 'user2_unread_count']: 0
          })
          .eq('id', conversationId);
      }
    } catch (error: any) {
      console.error('Error marking messages as read:', error);
    }
  };

  const sendMessage = async () => {
    if (!user || !selectedConversation || !newMessage.trim()) return;

    const conversation = conversations.find(c => c.id === selectedConversation);
    if (!conversation) return;

    const receiverId = conversation.user1_id === user.id ? conversation.user2_id : conversation.user1_id;

    try {
      setSending(true);
      const { data, error } = await supabase
        .from('messages')
        .insert([{
          sender_id: user.id,
          receiver_id: receiverId,
          conversation_id: selectedConversation,
          advertisement_id: conversation.advertisement_id,
          content: newMessage.trim()
        }])
        .select()
        .single();

      if (error) throw error;

      setMessages(prev => [...prev, data]);
      setNewMessage('');
      
      // Update conversations list
      fetchConversations();
    } catch (error: any) {
      toast.error('Помилка відправки повідомлення: ' + error.message);
    } finally {
      setSending(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  if (!user) return null;

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="max-w-4xl h-[600px] p-0">
        <div className="flex h-full">
          {/* Conversations List */}
          <div className="w-1/3 border-r border-border bg-background-secondary">
            <DialogHeader className="p-4 border-b border-border">
              <DialogTitle className="flex items-center gap-2">
                <MessageCircle className="w-5 h-5" />
                Повідомлення
              </DialogTitle>
            </DialogHeader>
            
            <ScrollArea className="h-[calc(100%-80px)]">
              <div className="p-2">
                {loading ? (
                  <div className="space-y-2">
                    {[...Array(3)].map((_, i) => (
                      <div key={i} className="h-16 bg-muted rounded-lg animate-pulse" />
                    ))}
                  </div>
                ) : conversations.length > 0 ? (
                  <div className="space-y-1">
                    {conversations.map((conv) => {
                      const unreadCount = conv.user1_id === user.id 
                        ? conv.user1_unread_count 
                        : conv.user2_unread_count;
                      
                      return (
                        <motion.div
                          key={conv.id}
                          whileHover={{ scale: 1.02 }}
                          className={`p-3 rounded-lg cursor-pointer transition-all ${
                            selectedConversation === conv.id 
                              ? 'bg-accent text-accent-foreground' 
                              : 'hover:bg-muted'
                          }`}
                          onClick={() => setSelectedConversation(conv.id)}
                        >
                          <div className="flex items-center justify-between mb-1">
                            <div className="flex items-center gap-2">
                              <User className="w-4 h-4" />
                              <span className="font-medium text-sm">
                                {conv.other_user?.nickname || 'Невідомий користувач'}
                              </span>
                              {conv.other_user?.role !== 'user' && (
                                <Badge variant="outline" className="text-xs">
                                  {conv.other_user?.role}
                                </Badge>
                              )}
                            </div>
                            {unreadCount > 0 && (
                              <Badge variant="destructive" className="text-xs">
                                {unreadCount}
                              </Badge>
                            )}
                          </div>
                          {conv.advertisement && (
                            <p className="text-xs text-muted-foreground truncate">
                              Про: {conv.advertisement.title}
                            </p>
                          )}
                          <p className="text-xs text-muted-foreground">
                            {new Date(conv.updated_at).toLocaleDateString('uk-UA')}
                          </p>
                        </motion.div>
                      );
                    })}
                  </div>
                ) : (
                  <div className="text-center py-8 text-muted-foreground">
                    <MessageCircle className="w-12 h-12 mx-auto mb-2 opacity-50" />
                    <p>Поки що немає розмов</p>
                  </div>
                )}
              </div>
            </ScrollArea>
          </div>

          {/* Messages Area */}
          <div className="flex-1 flex flex-col">
            {selectedConversation ? (
              <>
                {/* Messages */}
                <ScrollArea className="flex-1 p-4">
                  <div className="space-y-4">
                    <AnimatePresence>
                      {messages.map((message) => (
                        <motion.div
                          key={message.id}
                          initial={{ opacity: 0, y: 20 }}
                          animate={{ opacity: 1, y: 0 }}
                          className={`flex ${
                            message.sender_id === user.id ? 'justify-end' : 'justify-start'
                          }`}
                        >
                          <div
                            className={`max-w-xs lg:max-w-md px-4 py-2 rounded-2xl ${
                              message.sender_id === user.id
                                ? 'bg-accent text-accent-foreground'
                                : 'bg-muted'
                            }`}
                          >
                            <p className="text-sm">{message.content}</p>
                            <p className="text-xs opacity-70 mt-1">
                              {new Date(message.created_at).toLocaleTimeString('uk-UA', {
                                hour: '2-digit',
                                minute: '2-digit'
                              })}
                            </p>
                          </div>
                        </motion.div>
                      ))}
                    </AnimatePresence>
                    <div ref={messagesEndRef} />
                  </div>
                </ScrollArea>

                {/* Message Input */}
                <div className="p-4 border-t border-border">
                  <div className="flex gap-2">
                    <Input
                      value={newMessage}
                      onChange={(e) => setNewMessage(e.target.value)}
                      onKeyPress={handleKeyPress}
                      placeholder="Введіть повідомлення..."
                      className="flex-1 rounded-2xl"
                      disabled={sending}
                    />
                    <Button
                      onClick={sendMessage}
                      disabled={!newMessage.trim() || sending}
                      className="btn-accent rounded-2xl hover:scale-105 transition-transform"
                    >
                      <Send className="w-4 h-4" />
                    </Button>
                  </div>
                </div>
              </>
            ) : (
              <div className="flex-1 flex items-center justify-center text-muted-foreground">
                <div className="text-center">
                  <MessageCircle className="w-16 h-16 mx-auto mb-4 opacity-50" />
                  <p>Оберіть розмову для перегляду повідомлень</p>
                </div>
              </div>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default MessagingModal;