-- The first restock RPC returned void. This version returns the updated stock
-- so clients receive an explicit successful response after the write.

create or replace function public.restock_product_v2(
  p_product_id uuid,
  p_quantity integer
)
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_stock integer;
begin
  if not public.is_admin() then
    raise exception 'Only admins can restock products';
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
