-- Adds a public-facing username while keeping the Auth email private.

alter table public.profiles
  add column if not exists username text,
  add column if not exists login_email text;

update public.profiles p
set
  username = lower(regexp_replace(trim(coalesce(nullif(p.display_name, ''), split_part(u.email, '@', 1))), '\\s+', '', 'g')),
  login_email = u.email
from auth.users u
where p.id = u.id
  and (p.username is null or p.login_email is null);

alter table public.profiles
  alter column username set not null,
  alter column login_email set not null;

create unique index if not exists profiles_username_unique_idx
  on public.profiles (lower(username));

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_display_name text;
  v_username text;
begin
  v_display_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    split_part(new.email, '@', 1)
  );
  v_username := lower(regexp_replace(v_display_name, '\s+', '', 'g'));

  insert into public.profiles (id, display_name, username, login_email, role)
  values (new.id, v_display_name, v_username, new.email, 'staff');
  return new;
end;
$$;

-- Make the requested usernames explicit for existing seed accounts.
update public.profiles p
set username = case u.email
  when 'putri@gmail.com' then 'putri'
  when 'rapi@gmail.com' then 'rapi'
  else p.username
end
from auth.users u
where p.id = u.id;
