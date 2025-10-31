# Налаштування бази даних Supabase

## Статус
✅ База даних повністю налаштована та готова до роботи!

## Створені таблиці

### 1. `users` - Користувачі
- `id` (uuid) - Унікальний ID
- `nickname` (text, унікальний) - Нікнейм
- `password_hash` (text) - Хеш пароля
- `role` (enum) - Роль: user, vip, moderator, admin, Legend
- `is_banned` (boolean) - Статус блокування
- `created_at` (timestamptz) - Дата реєстрації

**RLS Policies:**
- Всі можуть читати профілі користувачів
- Користувачі можуть оновлювати свій профіль
- Реєстрація через RPC функцію

### 2. `advertisements` - Оголошення
- `id` (uuid) - Унікальний ID
- `user_id` (uuid) - ID автора
- `category` (text) - Категорія
- `subcategory` (text) - Підкатегорія
- `title` (text) - Назва
- `description` (text) - Опис
- `images` (text[]) - Масив URL зображень
- `discord_contact` (text) - Discord
- `telegram_contact` (text) - Telegram
- `price` (numeric) - Ціна
- `is_vip` (boolean) - VIP статус
- `created_at` (timestamptz) - Дата створення

**RLS Policies:**
- Всі можуть читати оголошення
- Користувачі можуть створювати оголошення
- Автори можуть редагувати/видаляти свої оголошення

### 3. `admin_logs` - Логи адміністрації
- `id` (uuid) - Унікальний ID
- `admin_id` (uuid) - ID адміністратора
- `action` (text) - Тип дії
- `target_user_id` (uuid) - ID цільового користувача
- `details` (jsonb) - Деталі дії
- `created_at` (timestamptz) - Час дії

**RLS Policies:**
- Тільки автентифіковані можуть читати логи
- Система може додавати нові логи

## Storage Bucket

### `advertisement-images`
- Публічний доступ для читання
- Максимальний розмір файлу: 5MB
- Дозволені формати: JPEG, PNG, GIF, WebP

**Storage Policies:**
- Всі можуть переглядати зображення
- Автентифіковані можуть завантажувати

## Допоміжні функції

### `set_app_user(user_id text)`
Встановлює контекст користувача для RLS

### `create_advertisement(...)`
Створює нове оголошення з перевіркою прав доступу

## Підключення

База даних вже підключена через:
- `src/integrations/supabase/client.ts`
- Змінні оточення в `.env` (якщо потрібно)

## Готово до використання!

Сайт повністю працює з Supabase:
- ✅ Реєстрація та вхід користувачів
- ✅ Створення та перегляд оголошень
- ✅ Завантаження зображень
- ✅ Адміністрування
- ✅ Система логів
- ✅ RLS захист даних
