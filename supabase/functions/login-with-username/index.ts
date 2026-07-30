import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const headers = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers });
  if (request.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers });
  }

  try {
    const { username, password } = await request.json();
    const normalizedUsername = String(username ?? '').trim().toLowerCase();
    if (!normalizedUsername || !password) {
      return new Response(JSON.stringify({ error: 'Invalid username or password.' }), { status: 400, headers });
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: profile } = await admin
      .from('profiles')
      .select('login_email')
      .ilike('username', normalizedUsername)
      .maybeSingle();

    // Keep failures deliberately generic so usernames cannot be enumerated.
    if (!profile?.login_email) {
      return new Response(JSON.stringify({ error: 'Invalid username or password.' }), { status: 401, headers });
    }

    const auth = createClient(supabaseUrl, publishableKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data, error } = await auth.auth.signInWithPassword({
      email: profile.login_email,
      password: String(password),
    });
    if (error || !data.session) {
      return new Response(JSON.stringify({ error: 'Invalid username or password.' }), { status: 401, headers });
    }

    return new Response(JSON.stringify({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
    }), { status: 200, headers });
  } catch (_) {
    return new Response(JSON.stringify({ error: 'Could not sign in. Try again.' }), { status: 500, headers });
  }
});
