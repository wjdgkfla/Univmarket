-- Accepting an offer reserves the listing, but nothing could ever move it on:
-- the owner update policy only covers available listings. Let the seller
-- finish a reservation as sold, or cancel it and relist the item.
create function app_private.finish_reservation(p_listing_id text, p_outcome text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor text := auth.uid()::text;
  txn public.transactions;
  affected text[];
begin
  if actor is null or app_private.member_university(actor) is null then
    raise exception 'University access required' using errcode = '42501';
  end if;
  if p_outcome is null or p_outcome not in ('sold', 'cancelled') then
    raise exception 'Invalid action' using errcode = '22023';
  end if;

  select t.* into txn from public.transactions t
  join public.transaction_listings tl on tl.transaction_id = t.id
  where tl.listing_id = p_listing_id and tl.role = 'target' and tl.is_active;
  if txn.id is null or txn.seller_id <> actor then
    raise exception 'Listing unavailable' using errcode = '42501';
  end if;

  -- Same lock order as respond_to_offer: listings by id, then the row itself.
  select array_agg(listing_id order by listing_id) into affected
  from public.transaction_listings where transaction_id = txn.id;
  perform id from public.listings where id = any(affected) order by id for update;
  select * into txn from public.transactions where id = txn.id for update;
  if txn.status not in ('reserved', 'meetup_scheduled') then
    raise exception 'Listing unavailable' using errcode = '42501';
  end if;

  update public.transaction_listings set is_active = false where transaction_id = txn.id;
  if p_outcome = 'sold' then
    update public.transactions
      set status = 'completed', completed_at = now(), updated_at = now()
      where id = txn.id;
    update public.listings set status = 'sold' where id = any(affected);
  else
    update public.transactions
      set status = 'cancelled', cancelled_at = now(), cancelled_by = actor, updated_at = now()
      where id = txn.id;
    update public.listings set status = 'available' where id = any(affected);
  end if;

  insert into public.messages (conversation_id, from_user_id, to_user_id, body, type)
  select o.conversation_id, actor, txn.buyer_id,
    case p_outcome when 'sold' then 'Marked as sold' else 'Reservation cancelled' end,
    'system'
  from public.offers o where o.id = txn.offer_id;
end $$;

create function public.finish_reservation(p_listing_id text, p_outcome text)
returns void
language sql security invoker set search_path = '' as $$
  select app_private.finish_reservation(p_listing_id, p_outcome)
$$;

revoke all on function app_private.finish_reservation(text, text) from public, anon, authenticated;
grant execute on function app_private.finish_reservation(text, text) to authenticated, service_role;
revoke execute on function public.finish_reservation(text, text) from public, anon;
grant execute on function public.finish_reservation(text, text) to authenticated;
notify pgrst, 'reload schema';
