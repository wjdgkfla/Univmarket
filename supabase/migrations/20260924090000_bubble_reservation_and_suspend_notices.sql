-- finish_reservation and admin_resolve_report's suspend path both write a
-- system message into public.messages when a reservation resolves or an
-- offer is withdrawn, but neither ever bumps the conversation's
-- last_message/updated_at the way every other message-producing path in
-- this codebase does (send_message, send_offer, respond_to_offer,
-- decline_offers_on_unavailable, expire_offers). Left as-is, the buyer or
-- seller sees the system message once they happen to open that specific
-- thread, but the thread never sorts to the top of their Inbox — easy to
-- miss entirely among several open chats. admin_resolve_report's own
-- offer-withdrawal branch (suspending a user withdraws their pending
-- offers elsewhere) additionally never wrote a message at all, so the
-- counterparty's Accept/Decline buttons on that offer silently stop
-- working with zero explanation.
create or replace function app_private.finish_reservation(p_listing_id text, p_outcome text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor text := auth.uid()::text;
  txn public.transactions;
  affected text[];
  conv text;
  note text;
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

  note := case p_outcome when 'sold' then 'Marked as sold' else 'Reservation cancelled' end;
  select o.conversation_id into conv from public.offers o where o.id = txn.offer_id;
  insert into public.messages (conversation_id, from_user_id, to_user_id, body, type)
  values (conv, actor, txn.buyer_id, note, 'system');
  update public.conversations set last_message = note, updated_at = now() where id = conv;
end $$;

create or replace function app_private.admin_resolve_report(p_report_id text, p_action text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor text := auth.uid()::text;
  university uuid := app_private.admin_university();
  report public.reports;
  suspended text;
  deal record;
  offer record;
  affected text[];
  conv text;
begin
  if p_action is null or p_action not in ('dismiss', 'hide_listing', 'suspend_user') then
    raise exception 'Invalid action' using errcode = '22023';
  end if;
  select r.* into report from public.reports r
  join public.profiles p on p.id = r.reported_user_id
  where r.id = p_report_id and r.status = 'open' and p.university_id = university
  for update of r;
  if report.id is null then
    raise exception 'Report unavailable' using errcode = '42501';
  end if;

  if p_action = 'dismiss' then
    update public.reports set status = 'resolved' where id = report.id;
  elsif p_action = 'hide_listing' then
    if report.listing_id is null then
      raise exception 'Invalid action' using errcode = '22023';
    end if;
    update public.listings set moderation_state = 'hidden' where id = report.listing_id;
    update public.reports set status = 'resolved'
      where listing_id = report.listing_id and status = 'open';
  else
    if report.reported_user_id = actor or exists (
      select 1 from public.profiles
      where id = report.reported_user_id and role = 'admin'
    ) then
      raise exception 'Admins cannot be suspended here' using errcode = '42501';
    end if;
    suspended := report.reported_user_id;

    -- Unwind reservations the suspended student is part of, either side.
    -- Lock order matches respond_to_offer/delete_my_account.
    for deal in
      select t.id, t.offer_id, t.buyer_id, t.seller_id from public.transactions t
      where suspended in (t.buyer_id, t.seller_id)
        and t.status in ('reserved', 'meetup_scheduled')
      order by t.id
    loop
      select array_agg(listing_id order by listing_id) into affected
      from public.transaction_listings where transaction_id = deal.id;
      perform id from public.listings where id = any(affected) order by id for update;
      update public.transaction_listings set is_active = false where transaction_id = deal.id;
      update public.transactions
        set status = 'cancelled', cancelled_at = now(), cancelled_by = actor,
            cancellation_reason = 'account suspended', updated_at = now()
        where id = deal.id;
      update public.listings set status = 'available'
        where id = any(affected) and status = 'reserved';

      select o.conversation_id into conv from public.offers o where o.id = deal.offer_id;
      if conv is not null then
        insert into public.messages (conversation_id, from_user_id, to_user_id, body, type)
        values (
          conv, actor,
          case when deal.buyer_id = suspended then deal.seller_id else deal.buyer_id end,
          'Reservation cancelled', 'system'
        );
        update public.conversations set last_message = 'Reservation cancelled', updated_at = now()
          where id = conv;
      end if;
    end loop;

    -- Withdraw any pending offer the suspended student is still a party to
    -- elsewhere, and tell the other side in their own thread — same
    -- courtesy expire_offers and decline_offers_on_unavailable already give
    -- an auto-declined offer, so Accept/Decline doesn't just go dead.
    for offer in
      select id, conversation_id, from_user_id, to_user_id from public.offers
      where status = 'pending' and suspended in (from_user_id, to_user_id)
    loop
      update public.offers set status = 'withdrawn' where id = offer.id;
      insert into public.messages (conversation_id, from_user_id, to_user_id, body, type)
      values (
        offer.conversation_id, actor,
        case when offer.from_user_id = suspended then offer.to_user_id else offer.from_user_id end,
        'Offer withdrawn', 'system'
      );
      update public.conversations set last_message = 'Offer withdrawn', updated_at = now()
        where id = offer.conversation_id;
    end loop;

    update public.profiles set account_state = 'suspended'
      where id = suspended and account_state = 'active';
    -- Fires decline_offers_on_unavailable per listing, which declines and
    -- messages any pending offers on the suspended seller's own listings.
    update public.listings set moderation_state = 'hidden'
      where seller_id = suspended and moderation_state = 'visible';
    update public.reports set status = 'resolved'
      where reported_user_id = suspended and status = 'open';
  end if;

  insert into public.admin_activity (actor_user_id, action, target_type, target_id, notes)
  values (actor, p_action, 'report', report.id,
    case p_action
      when 'hide_listing' then 'listing ' || report.listing_id
      when 'suspend_user' then 'user ' || report.reported_user_id
    end);
end $$;

notify pgrst, 'reload schema';
