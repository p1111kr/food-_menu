-- Create Categories Table
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  color text not null,
  gradient_start text not null,
  gradient_end text not null,
  scope text not null default 'public',
  created_at timestamp with time zone not null default now(),
  constraint categories_scope_check check (scope in ('public', 'personal'))
);

alter table public.categories enable row level security;

create policy "Anyone can read public categories"
on public.categories for select
to anon, authenticated
using (scope = 'public');

-- Seed initial data with proper UUIDs
insert into public.categories (title, color, gradient_start, gradient_end)
values 
  ('Italian', 'purple', '#9c27b0', '#6a1b9a'),
  ('Quick & easy', 'red', '#f44336', '#b71c1c'),
  ('Ethiopian', 'lightGreen', '#8bc34a', '#33691e'),
  ('German', 'amber', '#ffc107', '#ff8f00'),
  ('Light & Lovely', 'blue', '#2196f3', '#0d47a1'),
  ('Exotic', 'green', '#4caf50', '#1b5e20'),
  ('Breakfast', 'lightBlue', '#03a9f4', '#01579b'),
  ('Asian', 'orange', '#ff9800', '#e65100'),
  ('French', 'pink', '#e91e63', '#880e4f'),
  ('Summer', 'teal', '#009688', '#004d40');

notify pgrst, 'reload schema';