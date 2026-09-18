-- Record when the caller last read a conversation so the Inbox unread dot
-- clears. Same authorization as sending a message (participant, verified
-- same-university membership, not blocked).
create function app_private.mark_conversation_read(p_conversation_id text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor text:=auth.uid()::text;
  conversation public.conversations;
begin
  conversation:=app_private.authorized_conversation(p_conversation_id);
  update public.conversations set
    buyer_last_read_at = case when actor=conversation.buyer_id then now() else buyer_last_read_at end,
    seller_last_read_at = case when actor=conversation.seller_id then now() else seller_last_read_at end
  where id=p_conversation_id;
end $$;

create function public.mark_conversation_read(p_conversation_id text) returns void
language sql security invoker set search_path='' as $$ select app_private.mark_conversation_read(p_conversation_id) $$;

revoke all on function app_private.mark_conversation_read(text) from public, anon, authenticated;
grant execute on function app_private.mark_conversation_read(text) to authenticated, service_role;
revoke execute on function public.mark_conversation_read(text) from public, anon;
grant execute on function public.mark_conversation_read(text) to authenticated, service_role;
notify pgrst, 'reload schema';
