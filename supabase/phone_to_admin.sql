-- Run once in Supabase > SQL Editor.
-- Makes sure the customer's phone number is stored on each order (orders.ship_phone) so the admin panel can show it.

-- 1) column (already exists in most setups)
alter table public.orders add column if not exists ship_phone text;

-- 2) lets a signed-in customer write the phone onto THEIR OWN order only
create or replace function public.save_order_phone(p_order_no text, p_phone text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_phone !~ '^09[0-9]{9}$' then raise exception 'invalid phone number'; end if;
  update public.orders
     set ship_phone = p_phone
   where order_no = p_order_no
     and user_id = auth.uid();
end;
$$;
revoke all on function public.save_order_phone(text, text) from public;
grant execute on function public.save_order_phone(text, text) to authenticated;

-- 3) backfill: orders placed earlier whose phone is empty, using the copy saved with the account at checkout
update public.orders o
   set ship_phone = u.raw_user_meta_data -> 'order_ship' -> o.order_no ->> 'phone'
  from auth.users u
 where u.id = o.user_id
   and coalesce(o.ship_phone, '') = ''
   and coalesce(u.raw_user_meta_data -> 'order_ship' -> o.order_no ->> 'phone', '') <> '';
