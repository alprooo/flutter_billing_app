#!/usr/bin/env node

// Creates the two development POS accounts through Supabase's Admin API.
// Required environment variables:
// SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, PUTRI_PASSWORD, RAPI_PASSWORD

const baseUrl = process.env.SUPABASE_URL?.replace(/\/$/, '');
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!baseUrl || !serviceRoleKey) {
  throw new Error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before running this script.');
}

const users = [
  {
    email: 'putri@gmail.com',
    password: process.env.PUTRI_PASSWORD,
    displayName: 'Putri',
    role: 'admin',
  },
  {
    email: 'rapi@gmail.com',
    password: process.env.RAPI_PASSWORD,
    displayName: 'Rapi',
    role: 'staff',
  },
];

if (users.some((user) => !user.password)) {
  throw new Error('Set both PUTRI_PASSWORD and RAPI_PASSWORD before running this script.');
}

const headers = {
  apikey: serviceRoleKey,
  Authorization: `Bearer ${serviceRoleKey}`,
  'Content-Type': 'application/json',
};

async function request(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {...headers, ...options.headers},
  });
  if (!response.ok) {
    throw new Error(`${options.method ?? 'GET'} ${path} failed: ${await response.text()}`);
  }
  return response.status === 204 ? null : response.json();
}

async function findOrCreateUser(user) {
  const data = await request('/auth/v1/admin/users?page=1&per_page=1000');
  const existing = data.users?.find((item) => item.email?.toLowerCase() === user.email);
  if (existing) return existing;
  return request('/auth/v1/admin/users', {
    method: 'POST',
    body: JSON.stringify({
      email: user.email,
      password: user.password,
      email_confirm: true,
      user_metadata: {display_name: user.displayName},
    }),
  });
}

for (const user of users) {
  const authUser = await findOrCreateUser(user);
  await request(`/rest/v1/profiles?id=eq.${authUser.id}`, {
    method: 'PATCH',
    headers: {Prefer: 'return=minimal'},
    body: JSON.stringify({display_name: user.displayName, role: user.role}),
  });
  console.log(`Seeded ${user.email} as ${user.role}.`);
}
