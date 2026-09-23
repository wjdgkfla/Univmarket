-- In-app account deletion (App Store guideline 5.1.1(v)).
-- Anonymize rather than erase: the other side of every chat keeps its
-- history, now from "Deleted student". Personal data and the sign-in are
-- removed, open deals are unwound, and the email can register again.
create function app_private.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor text := auth.uid()::text;
  deal record;
  affected text[];
begin
  if actor is null or not exists (
    select 1 from public.profiles where id = actor and deleted_at is null
  ) then
    raise exception 'Account unavailable' using errcode = '42501';
  end if;

  -- Cancel reservations the student is part of, so the other student's
  -- items go back on sale. Lock order matches respond_to_offer.
  for deal in
    select t.id from public.transactions t
    where actor in (t.buyer_id, t.seller_id)
      and t.status in ('reserved', 'meetup_scheduled')
    order by t.id
  loop
    select array_agg(listing_id order by listing_id) into affected
    from public.transaction_listings where transaction_id = deal.id;
    perform id from public.listings where id = any(affected) order by id for update;
    update public.transaction_listings set is_active = false where transaction_id = deal.id;
    update public.transactions
      set status = 'cancelled', cancelled_at = now(), cancelled_by = actor,
          cancellation_reason = 'account deleted', updated_at = now()
      where id = deal.id;
    update public.listings set status = 'available'
      where id = any(affected) and status = 'reserved';
  end loop;

  update public.offers set status = 'withdrawn'
    where status = 'pending' and actor in (from_user_id, to_user_id);
  update public.listings set deleted_at = now()
    where seller_id = actor and deleted_at is null;

  delete from public.favorites where user_id = actor;
  delete from public.blocks where blocker_id = actor;
  delete from public.saved_searches where user_id = actor;
  delete from public.price_watches where user_id = actor;
  delete from public.notifications where user_id = actor;
  delete from public.notification_preferences where user_id = actor;
  delete from public.device_push_tokens where user_id = actor;

  update public.profiles
    set display_name = 'Deleted student', bio = null, profile_image_url = null,
        account_state = 'deleted', deleted_at = now()
    where id = actor;

  -- Removes the sign-in (sessions and identities cascade). Profiles do not
  -- reference auth.users, so messages and reports keep their author row.
  delete from auth.users where id = auth.uid();
end $$;

create function public.delete_my_account() returns void
language sql security invoker set search_path = '' as $$
  select app_private.delete_my_account()
$$;

revoke all on function app_private.delete_my_account() from public, anon, authenticated;
grant execute on function app_private.delete_my_account() to authenticated, service_role;
revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
notify pgrst, 'reload schema';
