# Supabase setup

1. Create a Supabase project and run every SQL file in `migrations/` in filename order in the SQL editor (or apply them with the Supabase CLI). Existing projects that already ran the first migration must also run `202607300002_restock_product_rpc.sql`.
2. Deploy the username-login Edge Function after applying `202607300003_username_login.sql`:

   ```bash
   supabase functions deploy login-with-username --no-verify-jwt
   ```

   The function uses Supabase-managed `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` environment values; do not add the service-role key to the Flutter app.
3. Create your first user in Supabase Auth, then promote it in SQL:

   ```sql
   update public.profiles set role = 'admin' where id = '<auth-user-uuid>';
   ```

4. Run Flutter without committing keys:

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```

The anonymous key is designed for clients; RLS is the security boundary. Never put a Supabase service-role key in the app.

### Save the Flutter values once for local development

Copy the template and fill in only the Project URL and publishable key from **Project Settings → API**:

```bash
cp config/supabase.local.json.example config/supabase.local.json
```

Then run `./scripts/run_local.sh` whenever you want to test. The local JSON file is ignored by Git. Alternatively, select **Anugrah Ukui (local Supabase)** and press Run/Debug in VS Code.

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
