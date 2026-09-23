-- Push notifications, server side. Every notify-worthy event — a text
-- message, a sent offer, an accept/decline/withdraw, a reservation
-- finished, an offer auto-declined by someone else's sale — already writes
-- a row to public.messages addressed to the other party. So one trigger on
-- that table covers all of it, the same way queue_report_email covers every
-- report regardless of who filed it.
--
-- Same shape as report_email_alerts.sql: a random per-environment token in
-- Vault, a security-definer function that gathers what the edge function
-- needs (gated by that token), and an after-insert trigger that queues the
-- call. Needs 'project_url' in Vault (already set for photo cleanup/report
-- email) or nothing is queued, so local/CI rebuilds never call production.
select vault.create_secret(
  gen_random_uuid()::text || gen_random_uuid()::text,
  'push_notification_token',
  'Authorizes send-push calls from the messages trigger'
);

-- Null return means "don't send": no device registered, the recipient
-- turned this category off, or the message vanished (rolled back).
create function app_private.push_notification_details(p_token text, p_message_id text)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  m public.messages;
  pref public.notification_preferences;
  enabled boolean;
  sender_name text;
  listing_title text;
  tokens jsonb;
begin
  if p_token is null or not exists (
    select 1 from vault.decrypted_secrets
    where name = 'push_notification_token' and decrypted_secret = p_token
  ) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  select * into m from public.messages where id = p_message_id;
  if m.id is null then return null; end if;

  select * into pref from public.notification_preferences where user_id = m.to_user_id;
  -- No preferences row yet defaults to on, matching the table's own defaults.
  enabled := coalesce(case when m.type = 'offer' then pref.offers else pref.messages end, true);
  if not enabled then return null; end if;

  select coalesce(jsonb_agg(jsonb_build_object('platform', platform, 'token', token)), '[]'::jsonb)
    into tokens from public.device_push_tokens where user_id = m.to_user_id;
  if tokens = '[]'::jsonb then return null; end if;

  select display_name into sender_name from public.profiles where id = m.from_user_id;
  select l.title into listing_title from public.conversations c
    join public.listings l on l.id = c.listing_id where c.id = m.conversation_id;

  return jsonb_build_object(
    'tokens', tokens,
    'title', coalesce(sender_name, 'Someone')
      || case m.type when 'offer' then ' sent an offer' else ' sent a message' end,
    'body', case
      when m.type = 'system' then m.body
      when m.type = 'offer' then coalesce(listing_title, 'your listing')
      else left(m.body, 120)
    end,
    'link', '/chat/' || m.conversation_id
  );
end $$;

create function public.push_notification_details(p_token text, p_message_id text) returns jsonb
language sql stable security invoker set search_path = '' as $$
  select app_private.push_notification_details(p_token, p_message_id)
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
    body := jsonb_build_object('message_id', new.id))
  from vault.decrypted_secrets url, vault.decrypted_secrets token
  where url.name = 'project_url' and token.name = 'push_notification_token';
  return null;
end $$;
revoke all on function app_private.queue_push_notification() from public, anon, authenticated;

create trigger messages_queue_push
after insert on public.messages
for each row execute function app_private.queue_push_notification();

notify pgrst, 'reload schema';
