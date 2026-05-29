insert into storage.buckets (id, name, public)
values ('meal-images', 'meal-images', true)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "Authenticated users can upload meal images"
on storage.objects;

create policy "Authenticated users can upload meal images"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'meal-images');

drop policy if exists "Public users can read meal images"
on storage.objects;

create policy "Public users can read meal images"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'meal-images');
