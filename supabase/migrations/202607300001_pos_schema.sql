-- Run this migration in a Supabase project before launching the app.
-- Roles are assigned by trusted SQL/dashboard workflows only.

create extension if not exists pgcrypto;

create type public.app_role as enum ('admin', 'staff');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role public.app_role not null default 'staff',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  barcode text not null unique,
  name text not null,
  price numeric(14, 2) not null check (price >= 0),
  stock integer not null default 0 check (stock >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  client_transaction_id uuid not null unique,
  staff_id uuid not null references public.profiles(id),
  completed_at timestamptz not null default now(),
  total numeric(14, 2) not null check (total >= 0),
  shop_name text
);

create table public.transaction_items (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  barcode text not null,
  product_name text not null,
  unit_price numeric(14, 2) not null check (unit_price >= 0),
  quantity integer not null check (quantity > 0)
);

create index transactions_staff_completed_at_idx
  on public.transactions (staff_id, completed_at desc);
create index transaction_items_transaction_id_idx
  on public.transaction_items (transaction_id);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger products_set_updated_at before update on public.products
  for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    'staff'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_items enable row level security;

create policy "users read own profile or admins read all"
  on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
create policy "authenticated users read products"
  on public.products for select to authenticated using (true);
create policy "admins manage products"
  on public.products for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "staff read own transactions or admins read all"
  on public.transactions for select to authenticated
  using (staff_id = auth.uid() or public.is_admin());
create policy "staff read own transaction items or admins read all"
  on public.transaction_items for select to authenticated
  using (
    exists (
      select 1 from public.transactions t
      where t.id = transaction_id
        and (t.staff_id = auth.uid() or public.is_admin())
    )
  );

-- Atomically records a sale and decrements stock. The caller's user ID and
-- server time are authoritative; client-supplied totals and staff IDs are not.
create or replace function public.complete_checkout(
  p_client_transaction_id uuid,
  p_items jsonb,
  p_shop_name text default null
)
returns public.transactions
language plpgsql security definer set search_path = public as $$
declare
  v_existing public.transactions;
  v_transaction public.transactions;
  v_item jsonb;
  v_product public.products;
  v_quantity integer;
  v_total numeric(14, 2) := 0;
  v_seen_product_ids uuid[] := '{}';
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_existing from public.transactions
  where client_transaction_id = p_client_transaction_id;
  if found then
    if v_existing.staff_id <> auth.uid() then
      raise exception 'Transaction belongs to another user';
    end if;
    return v_existing;
  end if;

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'A sale requires at least one item';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_quantity := (v_item ->> 'quantity')::integer;
    if v_quantity <= 0 then raise exception 'Quantity must be positive'; end if;
    if (v_item ->> 'product_id')::uuid = any(v_seen_product_ids) then
      raise exception 'Each product may only appear once in a sale';
    end if;
    v_seen_product_ids := array_append(v_seen_product_ids, (v_item ->> 'product_id')::uuid);
    select * into v_product from public.products
      where id = (v_item ->> 'product_id')::uuid for update;
    if not found then raise exception 'Product not found'; end if;
    if v_product.stock < v_quantity then
      raise exception 'Insufficient stock for %', v_product.name;
    end if;
    v_total := v_total + (v_product.price * v_quantity);
  end loop;

  insert into public.transactions (client_transaction_id, staff_id, total, shop_name)
  values (p_client_transaction_id, auth.uid(), v_total, nullif(trim(p_shop_name), ''))
  returning * into v_transaction;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_quantity := (v_item ->> 'quantity')::integer;
    select * into v_product from public.products
      where id = (v_item ->> 'product_id')::uuid for update;
    update public.products set stock = stock - v_quantity where id = v_product.id;
    insert into public.transaction_items (
      transaction_id, product_id, barcode, product_name, unit_price, quantity
    ) values (
      v_transaction.id, v_product.id, v_product.barcode, v_product.name,
      v_product.price, v_quantity
    );
  end loop;
  return v_transaction;
end;
$$;

revoke all on function public.complete_checkout(uuid, jsonb, text) from public;
grant execute on function public.complete_checkout(uuid, jsonb, text) to authenticated;

create or replace function public.restock_product(p_product_id uuid, p_quantity integer)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Only admins can restock products'; end if;
  if p_quantity <= 0 then raise exception 'Quantity must be positive'; end if;
  update public.products set stock = stock + p_quantity where id = p_product_id;
  if not found then raise exception 'Product not found'; end if;
end;
$$;
revoke all on function public.restock_product(uuid, integer) from public;
grant execute on function public.restock_product(uuid, integer) to authenticated;

-- Admin-only validated bulk import. Existing barcodes are rejected so the
-- client can report row errors and prevent unexpected inventory overwrites.
create or replace function public.import_products(p_products jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v_item jsonb;
begin
  if not public.is_admin() then raise exception 'Only admins can import products'; end if;
  for v_item in select * from jsonb_array_elements(p_products)
  loop
    insert into public.products (barcode, name, price, stock)
    values (
      trim(v_item ->> 'barcode'), trim(v_item ->> 'name'),
      (v_item ->> 'price')::numeric, (v_item ->> 'stock')::integer
    );
  end loop;
end;
$$;
revoke all on function public.import_products(jsonb) from public;
grant execute on function public.import_products(jsonb) to authenticated;
