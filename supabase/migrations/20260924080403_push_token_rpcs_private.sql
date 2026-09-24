-- Match the project's pattern: definer logic in app_private, a thin
-- invoker wrapper in public for the REST API.
drop function public.register_push_token(text, text);
drop function public.unregister_push_token(text);

create function app_private.register_push_token(p_token text, p_platform text)
returns void
language plpgsql security definer set search_path = '' as $$
declare actor text := auth.uid()::text;
begin
  if actor is null then raise exception 'Not authenticated' using errcode = '42501'; end if;
  if p_platform not in ('ios', 'android') or length(p_token) not between 1 and 4096 then
    raise exception 'Invalid push token' using errcode = '22023';
  end if;
  -- A device token belongs to whoever signed in on it last.
  delete from public.device_push_tokens where token = p_token and user_id <> actor;
  insert into public.device_push_tokens (user_id, platform, token, last_seen_at)
  values (actor, p_platform, p_token, now())
  on conflict (user_id, token) do update set last_seen_at = now(), platform = excluded.platform;
end $$;

create function app_private.unregister_push_token(p_token text)
returns void
language sql security definer set search_path = '' as $$
  delete from public.device_push_tokens
  where token = p_token and user_id = auth.uid()::text
$$;

create function public.register_push_token(p_token text, p_platform text)
returns void language sql set search_path = '' as $$
  select app_private.register_push_token(p_token, p_platform) $$;
create function public.unregister_push_token(p_token text)
returns void language sql set search_path = '' as $$
  select app_private.unregister_push_token(p_token) $$;

revoke all on function app_private.register_push_token(text, text) from public, anon;
revoke all on function app_private.unregister_push_token(text) from public, anon;
revoke all on function public.register_push_token(text, text) from public, anon;
revoke all on function public.unregister_push_token(text) from public, anon;
grant execute on function app_private.register_push_token(text, text) to authenticated;
grant execute on function app_private.unregister_push_token(text) to authenticated;
grant execute on function public.register_push_token(text, text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;
notify pgrst, 'reload schema';
