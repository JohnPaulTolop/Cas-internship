-- Run this in the Supabase SQL editor after enabling the Firebase Auth
-- third-party integration for the same Firebase project.

insert into storage.buckets (id, name, public)
values ('internship-documents', 'internship-documents', false)
on conflict (id) do update set public = false;

-- Firebase UIDs are strings, not PostgreSQL UUIDs, so compare the JWT subject
-- as text instead of calling auth.uid(). Every object path begins with the UID.

drop policy if exists "Firebase users upload to their own folder" on storage.objects;
drop policy if exists "Owners and staff read internship documents" on storage.objects;
drop policy if exists "Owners replace their internship documents" on storage.objects;
drop policy if exists "Owners and admins delete internship documents" on storage.objects;
drop policy if exists "Owners and staff delete internship documents" on storage.objects;

create policy "Firebase users upload to their own folder"
on storage.objects for insert
to anon, authenticated
with check (
  bucket_id = 'internship-documents'
  and (auth.jwt()->>'sub') is not null
  and (storage.foldername(name))[1] = (auth.jwt()->>'sub')
);

create policy "Owners and staff read internship documents"
on storage.objects for select
to anon, authenticated
using (
  bucket_id = 'internship-documents'
  and (auth.jwt()->>'sub') is not null
  and (
    (storage.foldername(name))[1] = (auth.jwt()->>'sub')
    or (auth.jwt()->>'app_role') in ('admin', 'coordinator')
  )
);

create policy "Owners replace their internship documents"
on storage.objects for update
to anon, authenticated
using (
  bucket_id = 'internship-documents'
  and (storage.foldername(name))[1] = (auth.jwt()->>'sub')
)
with check (
  bucket_id = 'internship-documents'
  and (storage.foldername(name))[1] = (auth.jwt()->>'sub')
);

create policy "Owners and staff delete internship documents"
on storage.objects for delete
to anon, authenticated
using (
  bucket_id = 'internship-documents'
  and (
    (storage.foldername(name))[1] = (auth.jwt()->>'sub')
    or (auth.jwt()->>'app_role') in ('admin', 'coordinator')
  )
);
