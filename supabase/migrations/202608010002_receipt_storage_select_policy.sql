-- Apply this after 202608010001_receipt_storage.sql in projects where the
-- original receipt bucket migration was already run. Supabase Storage performs
-- INSERT ... RETURNING during upload, which needs a matching SELECT policy.
create policy "staff read their receipt image metadata"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
