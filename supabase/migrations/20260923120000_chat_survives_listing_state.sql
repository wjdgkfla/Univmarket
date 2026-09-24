-- Two related bugs: once a listing leaves 'available' (reserved, sold, or
-- soft-deleted/hidden), the chat about it becomes unreachable even for the
-- two people already in it.
--
-- 1. start_conversation re-validated the listing's current availability
--    every time, so "Message seller" on your own reserved/sold item's
--    thread (still shown in the UI) failed instead of reopening it.
-- 2. mark_conversation_read went through the same listing-visibility check
--    as sending a message, so a deleted/hidden listing's thread could
--    never have its unread dot cleared, even though reading the thread's
--    history (a plain RLS-scoped select, not this RPC) still worked fine.
--
-- Fix: an existing conversation is authorized by participancy once it
-- exists; the listing's availability only gates *creating* a new one.
-- Marking read never needed the listing check at all — only that both
-- sides are still real, allowed to talk, and not blocked.
create or replace function app_private.start_conversation(p_listing_id text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  actor text := auth.uid()::text;
  university uuid := app_private.member_university(actor);
  listing public.listings;
  result text;
begin
  if university is null then
    raise exception 'University access required' using errcode = '42501';
  end if;
  select id into result from public.conversations
    where listing_id = p_listing_id and buyer_id = actor;
  if result is not null then
    perform app_private.authorized_conversation(result);
    return result;
  end if;
  select * into listing from public.listings where id = p_listing_id;
  if listing.id is null or listing.seller_id = actor
    or listing.university_id is distinct from university
    or app_private.member_university(listing.seller_id) is distinct from university
    or listing.status <> 'available' or listing.moderation_state <> 'visible'
    or listing.deleted_at is not null
    or app_private.blocked(actor, listing.seller_id)
  then raise exception 'Listing unavailable' using errcode = '42501'; end if;
  insert into public.conversations(listing_id, buyer_id, seller_id)
  values (p_listing_id, actor, listing.seller_id) on conflict (listing_id, buyer_id) do nothing;
  select id into result from public.conversations
    where listing_id = p_listing_id and buyer_id = actor;
  perform app_private.authorized_conversation(result);
  return result;
end $$;

create or replace function app_private.mark_conversation_read(p_conversation_id text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor text := auth.uid()::text;
  university uuid := app_private.member_university(actor);
  conversation public.conversations;
begin
  select * into conversation from public.conversations where id = p_conversation_id;
  if university is null or conversation.id is null or not conversation.is_active
    or actor not in (conversation.buyer_id, conversation.seller_id)
    or app_private.member_university(conversation.buyer_id) is distinct from university
    or app_private.member_university(conversation.seller_id) is distinct from university
    or app_private.blocked(conversation.buyer_id, conversation.seller_id)
  then raise exception 'Conversation unavailable' using errcode = '42501'; end if;
  update public.conversations set
    buyer_last_read_at = case when actor = conversation.buyer_id then now() else buyer_last_read_at end,
    seller_last_read_at = case when actor = conversation.seller_id then now() else seller_last_read_at end
  where id = p_conversation_id;
end $$;

notify pgrst, 'reload schema';
