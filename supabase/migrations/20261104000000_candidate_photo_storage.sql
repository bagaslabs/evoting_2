begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'candidate-photos',
  'candidate-photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "superadmin uploads candidate photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'candidate-photos'
    and public.is_superadmin()
  );

create policy "superadmin reads candidate photo metadata"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'candidate-photos'
    and public.is_superadmin()
  );

create policy "superadmin deletes candidate photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'candidate-photos'
    and public.is_superadmin()
  );

commit;
