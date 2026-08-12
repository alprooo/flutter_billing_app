-- Transaction items keep a snapshot of the sold product's barcode, name,
-- unit price, and quantity. Allow inventory products to be deleted without
-- deleting or corrupting historical transactions.
alter table public.transaction_items
  alter column product_id drop not null;

alter table public.transaction_items
  drop constraint if exists transaction_items_product_id_fkey;

alter table public.transaction_items
  add constraint transaction_items_product_id_fkey
  foreign key (product_id)
  references public.products(id)
  on delete set null;
