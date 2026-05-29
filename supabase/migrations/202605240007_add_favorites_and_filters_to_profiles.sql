-- Add favorites and filters columns to profiles table
-- favorites: text[] — array of meal UUIDs the user has favorited
-- filters: jsonb — user's dietary filter preferences

alter table public.profiles
  add column if not exists favorites text[] not null default '{}',
  add column if not exists filters jsonb not null default '{
    "glutenFree": false,
    "lactoseFree": false,
    "vegan": false,
    "vegetarian": false
  }'::jsonb;

notify pgrst, 'reload schema';
