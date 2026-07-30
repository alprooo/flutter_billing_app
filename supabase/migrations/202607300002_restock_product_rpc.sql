-- Apply this migration to projects that already ran the initial POS schema
-- before the admin restock RPC was added.

create or replace function public.restock_product(p_product_id uuid, p_quantity integer)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can restock products';
  end if;

  if p_quantity <= 0 then
    raise exception 'Quantity must be positive';
  end if;

  update public.products
  set stock = stock + p_quantity
  where id = p_product_id;

  if not found then
    raise exception 'Product not found';
  end if;
end;
$$;

revoke all on function public.restock_product(uuid, integer) from public;
grant execute on function public.restock_product(uuid, integer) to authenticated;
