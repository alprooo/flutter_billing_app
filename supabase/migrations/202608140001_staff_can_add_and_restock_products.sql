-- Allow staff to create products and restock inventory while keeping
-- product edits, deletes, and CSV imports limited to admins.

create policy "authenticated users add products"
  on public.products for insert to authenticated
  with check (true);

create or replace function public.restock_product_v2(
  p_product_id uuid,
  p_quantity integer
)
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_stock integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_quantity <= 0 then
    raise exception 'Quantity must be positive';
  end if;

  update public.products
  set stock = stock + p_quantity
  where id = p_product_id
  returning stock into v_stock;

  if not found then
    raise exception 'Product not found';
  end if;

  return v_stock;
end;
$$;

revoke all on function public.restock_product_v2(uuid, integer) from public;
grant execute on function public.restock_product_v2(uuid, integer) to authenticated;
