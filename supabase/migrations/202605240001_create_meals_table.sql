create table if not exists public.meals (
  id text primary key default gen_random_uuid()::text,
  user_id uuid null references auth.users (id) on delete cascade,
  title text not null,
  image_url text not null,
  categories text[] not null default '{}',
  ingredients text[] not null default '{}',
  steps text[] not null default '{}',
  duration integer not null check (duration > 0),
  complexity text not null,
  affordability text not null,
  is_gluten_free boolean not null default false,
  is_lactose_free boolean not null default false,
  is_vegan boolean not null default false,
  is_vegetarian boolean not null default false,
  scope text not null default 'personal',
  created_at timestamp with time zone not null default now(),
  constraint meals_scope_check check (scope in ('public', 'personal'))
);

create index if not exists meals_user_id_idx on public.meals (user_id);
create index if not exists meals_scope_idx on public.meals (scope);

notify pgrst, 'reload schema';
