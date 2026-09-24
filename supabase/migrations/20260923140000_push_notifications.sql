-- Push notifications, matching Supabase's own example:
-- https://supabase.com/docs/guides/functions/examples/push-notifications
-- A row inserted into `notifications` triggers a call to the send-push Edge
-- Function, which looks up the recipient's FCM token and delivers through
-- Firebase Cloud Messaging's HTTP v1 API (an OAuth token via
-- google-auth-library, not the heavier firebase-admin SDK — see
-- supabase/functions/send-push/index.ts).
--
-- Two differences from that example, both existing project conventions
-- kept instead of replaced:
--   - The call is queued by a Vault-token + pg_net trigger, the same
--     pattern every other Edge Function call in this project already
--     uses (report_email_alerts, listing_photo_cleanup), instead of a
--     Dashboard-configured Database Webhook. They do the same thing; this
--     one is captured in a migration, so it exists identically in local
--     dev, CI, and production, and CI can actually test it — a
--     Dashboard-only webhook would exist only in whichever project someone
--     clicked it into, and would need its target URL and auth header
--     hardcoded into a committed file to be captured any other way.
--   - device_push_tokens (multiple tokens per user) is replaced by the
--     example's single profiles.fcm_token column, as asked for. A user
--     signed in on two devices only gets push on whichever signed in
--     last — a real trade-off of this schema, not a bug.
-- Retire the device_push_tokens-based push path (notify_on_message /
-- queue_push / push_details / register_push_token / unregister_push_token)
-- so it doesn't keep running alongside the trigger below and double-insert
-- a notification per message. conversations_read_notifications /
-- read_chat_notifications stays: it only marks notifications read and is
-- unrelated to how a device is registered.
drop trigger if exists messages_notify_recipient on public.messages;
drop trigger if exists notifications_queue_push on public.notifications;
drop function if exists app_private.notify_on_message();
drop function if exists app_private.queue_push();
drop function if exists public.push_details(text, text);
drop function if exists app_private.push_details(text, text);
drop function if exists public.register_push_token(text, text);
drop function if exists app_private.register_push_token(text, text);
drop function if exists public.unregister_push_token(text);
drop function if exists app_private.unregister_push_token(text);

alter table public.profiles add column fcm_token text;
grant update (fcm_token) on public.profiles to authenticated;
drop table if exists public.device_push_tokens;
delete from vault.secrets where name = 'push_token';

-- Every notify-worthy event (a text message, a sent offer, an
-- accept/decline/withdraw, a reservation finished, an offer auto-declined
-- by someone else's sale) already writes a row to public.messages
-- addressed to the other party, so one trigger on that table builds every
-- notification's content, instead of duplicating that logic across every
-- RPC that can produce one.
create function app_private.queue_notification() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  pref public.notification_preferences;
  enabled boolean;
  sender_name text;
  listing_title text;
begin
  select * into pref from public.notification_preferences where user_id = new.to_user_id;
  -- No preferences row yet defaults to on, matching the table's own defaults.
  enabled := coalesce(case when new.type = 'offer' then pref.offers else pref.messages end, true);
  if not enabled then return null; end if;

  select display_name into sender_name from public.profiles where id = new.from_user_id;
  select l.title into listing_title from public.conversations c
    join public.listings l on l.id = c.listing_id where c.id = new.conversation_id;

  insert into public.notifications(user_id, type, title, body, link)
  values (
    new.to_user_id,
    new.type,
    coalesce(sender_name, 'Someone')
      || case new.type when 'offer' then ' sent an offer' else ' sent a message' end,
    case
      when new.type = 'system' then new.body
      when new.type = 'offer' then coalesce(listing_title, 'your listing')
      else left(new.body, 120)
    end,
    '/chat/' || new.conversation_id
  );
  return null;
end $$;
revoke all on function app_private.queue_notification() from public, anon, authenticated;

create trigger messages_queue_notification
after insert on public.messages
for each row execute function app_private.queue_notification();

-- Random per-environment token; only this database and its trigger know it.
select vault.create_secret(
  gen_random_uuid()::text || gen_random_uuid()::text,
  'push_notification_token',
  'Authorizes send-push calls from the notifications trigger'
);

-- Null return means "don't send": the notification vanished (rolled back)
-- or its recipient has no registered device.
create function app_private.push_notification_details(p_token text, p_notification_id text)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  n public.notifications;
  token text;
begin
  if p_token is null or not exists (
    select 1 from vault.decrypted_secrets
    where name = 'push_notification_token' and decrypted_secret = p_token
  ) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  select * into n from public.notifications where id = p_notification_id;
  if n.id is null then return null; end if;
  select fcm_token into token from public.profiles where id = n.user_id;
  if token is null then return null; end if;
  return jsonb_build_object('token', token, 'title', n.title, 'body', n.body, 'link', n.link);
end $$;

create function public.push_notification_details(p_token text, p_notification_id text) returns jsonb
language sql stable security invoker set search_path = '' as $$
  select app_private.push_notification_details(p_token, p_notification_id)
$$;
revoke all on function app_private.push_notification_details(text, text) from public, anon, authenticated;
grant execute on function app_private.push_notification_details(text, text) to service_role;
revoke all on function public.push_notification_details(text, text) from public, anon, authenticated;
grant execute on function public.push_notification_details(text, text) to service_role;

create function app_private.queue_push_notification() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform net.http_post(
    url := url.decrypted_secret || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-token', token.decrypted_secret),
    body := jsonb_build_object('notification_id', new.id))
  from vault.decrypted_secrets url, vault.decrypted_secrets token
  where url.name = 'project_url' and token.name = 'push_notification_token';
  return null;
end $$;
revoke all on function app_private.queue_push_notification() from public, anon, authenticated;

create trigger notifications_send_push
after insert on public.notifications
for each row execute function app_private.queue_push_notification();

-- device_push_tokens is gone; clear the sign-in's device instead.
create or replace function app_private.delete_my_account() returns void
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

  update public.profiles
    set display_name = 'Deleted student', bio = '', profile_image_url = null,
        fcm_token = null, account_state = 'deleted', deleted_at = now()
    where id = actor;

  -- Removes the sign-in (sessions and identities cascade). Profiles do not
  -- reference auth.users, so messages and reports keep their author row.
  delete from auth.users where id = auth.uid();
end $$;

notify pgrst, 'reload schema';
