create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  role text not null default 'user',
  created_at timestamp with time zone not null default now(),
  constraint profiles_role_check check (role in ('user', 'admin'))
);

alter table public.profiles enable row level security;

create policy "Users can read their own profile"
on public.profiles
for select
to authenticated
using (auth.uid() = id);

create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);
