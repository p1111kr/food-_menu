alter table public.meals enable row level security;

create policy "Anyone can read public meals"
on public.meals
for select
to anon, authenticated
using (scope = 'public');

create policy "Authenticated users can insert personal meals"
on public.meals
for insert
to authenticated
with check (
  auth.uid() = user_id
  and scope = 'personal'
);

create policy "Users can read their own personal meals"
on public.meals
for select
to authenticated
using (
  auth.uid() = user_id
  and scope = 'personal'
);

create policy "Only admins can insert public meals"
on public.meals
for insert
to authenticated
with check (
  scope = 'public'
  and exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'admin'
  )
);
