-- Bug B5: deleting your own account unwinds every reservation you're part
-- of (see delete_my_account), but a moderator suspending someone left their
-- open reservations exactly where they were — a buyer stuck waiting on a
-- seller who can no longer complete the sale, or a seller's item stuck
-- "reserved" to a buyer who can no longer complete the purchase. Same
-- unwind loop, scoped to the reported user instead of auth.uid(), and
-- cancelled_by the admin who acted.
--
-- Hiding the suspended user's own listings already declines their pending
-- offers for free, via decline_offers_on_unavailable's trigger on
-- listings.moderation_state — this only needs to additionally cover their
-- reservations (a separate table, untouched by that trigger) and any
-- pending offer they're still a party to elsewhere.
create or replace function app_private.admin_resolve_report(p_report_id text, p_action text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor text := auth.uid()::text;
  university uuid := app_private.admin_university();
  report public.reports;
  suspended text;
  deal record;
  affected text[];
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
      select t.id from public.transactions t
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
    end loop;

    update public.offers set status = 'withdrawn'
      where status = 'pending' and suspended in (from_user_id, to_user_id);
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
