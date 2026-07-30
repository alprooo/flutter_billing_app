# Supabase setup

1. Create a Supabase project and run `migrations/202607300001_pos_schema.sql` in the SQL editor (or with the Supabase CLI).
2. Create your first user in Supabase Auth, then promote it in SQL:

   ```sql
   update public.profiles set role = 'admin' where id = '<auth-user-uuid>';
   ```

3. Run Flutter without committing keys:

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```

The anonymous key is designed for clients; RLS is the security boundary. Never put a Supabase service-role key in the app.

## Seed the development users

The `scripts/seed_users.mjs` script creates confirmed Auth users and updates the profiles created by the migration trigger. It is idempotent, so it can be run again without duplicating users.

```bash
SUPABASE_URL=https://your-project.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key \
PUTRI_PASSWORD='Test123' \
RAPI_PASSWORD='Test123' \
node scripts/seed_users.mjs
```

This creates `putri@gmail.com` as **admin** and `rapi@gmail.com` as **staff**. The service-role key is for this trusted local command only—never add it to Flutter build defines, app source, or Git.
