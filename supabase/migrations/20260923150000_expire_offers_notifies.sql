-- Bug B4: the 10-minute cron job moved a stale offer to 'expired' but told
-- no one — a buyer's offer could just quietly stop working, and a seller's
-- Accept/Decline buttons could vanish, with no chat message explaining why
-- either happened. Same shape as decline_offers_on_unavailable: a system
-- message per affected conversation, and the conversation's own preview
-- updated so it isn't stuck showing the dead offer.
create or replace function app_private.expire_offers() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  expired record;
  n integer := 0;
begin
  for expired in
    update public.offers set status = 'expired'
    where status = 'pending' and expires_at <= now()
    returning id, conversation_id, from_user_id, to_user_id
  loop
    n := n + 1;
    insert into public.messages(conversation_id, from_user_id, to_user_id, body, type)
    values (expired.conversation_id, expired.to_user_id, expired.from_user_id, 'Offer expired', 'system');
    update public.conversations set last_message = 'Offer expired', updated_at = now()
      where id = expired.conversation_id;
  end loop;
  return n;
end $$;

notify pgrst, 'reload schema';
