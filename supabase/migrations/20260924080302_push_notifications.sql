select vault.create_secret(
  gen_random_uuid()::text || gen_random_uuid()::text,
  'push_token',
  'Authorizes push calls from the notifications trigger'
);

create function app_private.notify_on_message() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  sender text;
  item text;
  wanted bool;
begin
  select coalesce(case when new.type = 'text' then p.messages else p.offers end, true)
    into wanted
  from (select 1) one
  left join public.notification_preferences p on p.user_id = new.to_user_id;
  if not wanted then return null; end if;

  select coalesce(display_name, 'A student') into sender
  from public.profiles where id = new.from_user_id;
  select l.title into item
  from public.conversations c join public.listings l on l.id = c.listing_id
  where c.id = new.conversation_id;

  insert into public.notifications (user_id, type, title, body, link, meta)
  values (
    new.to_user_id,
    new.type,
    coalesce(sender, 'A student'),
    case new.type
      when 'text' then left(new.body, 140)
      when 'offer' then 'Offered $' || coalesce((
        select trim(to_char(o.cash_amount, 'FM999999990')) from public.offers o
        where o.id = new.offer_id), '?') || coalesce(' for ' || item, '')
      else new.body || coalesce(': ' || item, '')
    end,
    '/chat/' || new.conversation_id,
    jsonb_build_object('conversation_id', new.conversation_id, 'message_id', new.id)
  );
  return null;
exception when others then
  raise warning 'notify_on_message failed: %', sqlerrm;
  return null;
end $$;
revoke all on function app_private.notify_on_message() from public, anon, authenticated;

create trigger messages_notify_recipient
after insert on public.messages
for each row execute function app_private.notify_on_message();

create function app_private.queue_push() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform net.http_post(
    url := url.decrypted_secret || '/functions/v1/push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-token', token.decrypted_secret),
    body := jsonb_build_object('notification_id', new.id))
  from vault.decrypted_secrets url, vault.decrypted_secrets token
  where url.name = 'project_url' and token.name = 'push_token';
  return null;
exception when others then
  raise warning 'queue_push failed: %', sqlerrm;
  return null;
end $$;
revoke all on function app_private.queue_push() from public, anon, authenticated;

create trigger notifications_queue_push
after insert on public.notifications
for each row execute function app_private.queue_push();

create function app_private.push_details(p_token text, p_notification_id text)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_token is null or not exists (
    select 1 from vault.decrypted_secrets
    where name = 'push_token' and decrypted_secret = p_token
  ) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  return (
    select jsonb_build_object(
      'title', n.title,
      'body', n.body,
      'link', n.link,
      'type', n.type,
      'unread', (select count(*) from public.notifications u
                 where u.user_id = n.user_id and not u.is_read),
      'tokens', coalesce((select jsonb_agg(d.token) from public.device_push_tokens d
                          where d.user_id = n.user_id), '[]'::jsonb)
    )
    from public.notifications n where n.id = p_notification_id
  );
end $$;

create function public.push_details(p_token text, p_notification_id text)
returns jsonb
language sql stable security invoker set search_path = '' as $$
  select app_private.push_details(p_token, p_notification_id)
$$;
revoke all on function app_private.push_details(text, text) from public, anon, authenticated;
grant execute on function app_private.push_details(text, text) to service_role;
revoke all on function public.push_details(text, text) from public, anon, authenticated;
grant execute on function public.push_details(text, text) to service_role;

create function public.register_push_token(p_token text, p_platform text)
returns void
language plpgsql security definer set search_path = '' as $$
declare actor text := auth.uid()::text;
begin
  if actor is null then raise exception 'Not authenticated' using errcode = '42501'; end if;
  if p_platform not in ('ios', 'android') or length(p_token) not between 1 and 4096 then
    raise exception 'Invalid push token' using errcode = '22023';
  end if;
  delete from public.device_push_tokens where token = p_token and user_id <> actor;
  insert into public.device_push_tokens (user_id, platform, token, last_seen_at)
  values (actor, p_platform, p_token, now())
  on conflict (user_id, token) do update set last_seen_at = now(), platform = excluded.platform;
end $$;

create function public.unregister_push_token(p_token text)
returns void
language sql security definer set search_path = '' as $$
  delete from public.device_push_tokens
  where token = p_token and user_id = auth.uid()::text
$$;

revoke all on function public.register_push_token(text, text) from public, anon;
revoke all on function public.unregister_push_token(text) from public, anon;
grant execute on function public.register_push_token(text, text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;

create or replace function app_private.read_chat_notifications() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.notifications set is_read = true
  where not is_read and link = '/chat/' || new.id
    and user_id = case
      when new.buyer_last_read_at is distinct from old.buyer_last_read_at then new.buyer_id
      else new.seller_id end;
  return null;
end $$;
revoke all on function app_private.read_chat_notifications() from public, anon, authenticated;

create trigger conversations_read_notifications
after update of buyer_last_read_at, seller_last_read_at on public.conversations
for each row execute function app_private.read_chat_notifications();

create index if not exists notifications_user_unread_idx
  on public.notifications (user_id) where not is_read;
create index if not exists device_push_tokens_token_idx
  on public.device_push_tokens (token);

notify pgrst, 'reload schema';
