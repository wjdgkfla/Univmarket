-- Three offer-lifecycle bugs, all about a conversation going quiet or stale
-- for the person left holding a losing or spammed offer:
--
-- 1. respond_to_offer never touched conversations.updated_at, so accepting,
--    declining, or withdrawing an offer left that thread wherever it was in
--    the Inbox instead of bubbling it to the top like every other message.
-- 2. Accepting one offer silently declines every other pending offer on
--    the same listing, but never told those buyers — their chat just goes
--    stale with a button that (correctly) stops working.
-- 3. A buyer could stack unlimited pending offers on the same listing. A
--    fresh one now supersedes their last pending one instead: the app has
--    no withdraw button yet, so rejecting the new offer outright would trap
--    a buyer who changed their mind until the 48-hour expiry.
create or replace function app_private.respond_to_offer(p_offer_id text,p_action text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor text:=auth.uid()::text;
  offer public.offers;
  conversation public.conversations;
  transaction_id text;
  recipient text;
  affected text[];
  sibling record;
begin
  if actor is null or app_private.member_university(actor) is null then
    raise exception 'University access required' using errcode='42501'; end if;
  if p_action is null or p_action not in ('accept','decline','withdraw') then
    raise exception 'Invalid action' using errcode='22023'; end if;

  -- Lock all involved listings in a consistent order before locking the offer.
  -- This serializes competing reservations, including shared trade items.
  select array_agg(id order by id) into affected from (
    select listing_id as id from public.offers where id=p_offer_id
    union select offered_listing_id from public.offer_items where offer_id=p_offer_id
  ) ids;
  perform id from public.listings where id=any(affected) order by id for update;
  select * into offer from public.offers where id=p_offer_id for update;
  if offer.id is null then raise exception 'Offer unavailable' using errcode='42501'; end if;
  conversation:=app_private.authorized_conversation(offer.conversation_id);
  if offer.listing_id<>conversation.listing_id
    or not ((offer.from_user_id=conversation.buyer_id and offer.to_user_id=conversation.seller_id)
      or (offer.from_user_id=conversation.seller_id and offer.to_user_id=conversation.buyer_id))
    or (p_action='withdraw' and actor<>offer.from_user_id)
    or (p_action in ('accept','decline') and actor<>offer.to_user_id)
  then raise exception 'Not authorized to respond' using errcode='42501'; end if;
  if offer.status<>'pending' then raise exception 'Offer no longer pending' using errcode='22023'; end if;
  if p_action='accept' then
    if offer.expires_at is null or offer.expires_at<=now() then
      raise exception 'Offer expired' using errcode='22023'; end if;
    if exists(select 1 from public.listings l where l.id=any(affected) and (
      l.status<>'available' or l.deleted_at is not null or l.moderation_state<>'visible'
      or l.university_id is distinct from app_private.member_university(actor)
      or (l.id<>offer.listing_id and l.seller_id<>offer.from_user_id)))
      or exists(select 1 from public.transaction_listings where listing_id=any(affected) and is_active)
    then raise exception 'Listing unavailable' using errcode='42501'; end if;
    if (offer.kind='cash' and cardinality(affected)<>1)
      or (offer.kind in ('trade','trade_plus_cash') and cardinality(affected) not between 2 and 4)
    then raise exception 'Invalid offer contents' using errcode='22023'; end if;
    insert into public.transactions(listing_id,offer_id,buyer_id,seller_id,kind,agreed_price)
    values(offer.listing_id,offer.id,conversation.buyer_id,conversation.seller_id,
      case when offer.kind='cash' then 'sale' else 'trade' end,offer.cash_amount)
    returning id into transaction_id;
    insert into public.transaction_listings(transaction_id,listing_id,role)
    select transaction_id,i,case when i=offer.listing_id then 'target' else 'offered' end from unnest(affected) i;
    update public.listings set status='reserved' where id=any(affected);
    -- Every other buyer with a live offer on this listing loses it silently
    -- to whoever we just accepted; tell them, in their own thread.
    for sibling in
      select id, conversation_id, from_user_id, to_user_id
      from public.offers where listing_id=offer.listing_id and status='pending' and id<>offer.id
    loop
      update public.offers set status='declined' where id=sibling.id;
      insert into public.messages(conversation_id,from_user_id,to_user_id,body,type)
      values(sibling.conversation_id,conversation.seller_id,sibling.from_user_id,
        'This item was reserved for another offer','system');
      update public.conversations set last_message='This item was reserved for another offer',updated_at=now()
        where id=sibling.conversation_id;
    end loop;
    update public.offers set status='accepted' where id=offer.id;
  else
    update public.offers set status=case when p_action='decline' then 'declined' else 'withdrawn' end where id=offer.id;
  end if;
  recipient:=case when actor=offer.from_user_id then offer.to_user_id else offer.from_user_id end;
  insert into public.messages(conversation_id,from_user_id,to_user_id,body,type)
  values(offer.conversation_id,actor,recipient,
    case p_action when 'accept' then 'Offer accepted' when 'decline' then 'Offer declined' else 'Offer withdrawn' end,'system');
  -- Bug: this thread never bubbled to the top of the Inbox on any response,
  -- unlike every other message/offer path, which all touch updated_at.
  update public.conversations set
    last_message=case p_action when 'accept' then 'Offer accepted' when 'decline' then 'Offer declined' else 'Offer withdrawn' end,
    updated_at=now()
  where id=offer.conversation_id;
end $$;

create or replace function app_private.send_offer(p_conversation_id text,p_kind text,
  p_cash_amount numeric default 0,p_offered_listing_ids text[] default '{}') returns text
language plpgsql security definer set search_path = '' as $$
declare
  actor text:=auth.uid()::text;
  conversation public.conversations;
  result text;
  recipient text;
begin
  conversation:=app_private.authorized_conversation(p_conversation_id);
  if p_kind is null or p_kind not in ('cash','trade','trade_plus_cash')
    or p_cash_amount is null or p_cash_amount<0 or p_cash_amount>100000
    or p_offered_listing_ids is null or coalesce(array_ndims(p_offered_listing_ids),1)<>1
    or cardinality(p_offered_listing_ids)>3
    or (select count(distinct i) from unnest(p_offered_listing_ids) i)<>cardinality(p_offered_listing_ids)
    or (p_kind='cash' and cardinality(p_offered_listing_ids)<>0)
    or (p_kind in ('trade','trade_plus_cash') and cardinality(p_offered_listing_ids)=0)
    or (p_kind='trade' and p_cash_amount<>0)
  then raise exception 'Invalid offer contents' using errcode='22023'; end if;
  if not exists(select 1 from public.listings where id=conversation.listing_id and status='available') then
    raise exception 'Listing unavailable' using errcode='42501'; end if;
  -- A fresh offer replaces this buyer's last pending one on this listing.
  update public.offers set status='superseded'
    where conversation_id=p_conversation_id and from_user_id=actor and status='pending';
  if exists(select 1 from unnest(p_offered_listing_ids) i where not exists(
    select 1 from public.listings l where l.id=i and l.seller_id=actor
    and l.id<>conversation.listing_id and l.status='available'
    and l.university_id=app_private.member_university(actor)
    and l.moderation_state='visible' and l.deleted_at is null))
  then raise exception 'Offered listing unavailable' using errcode='42501'; end if;
  recipient:=case when actor=conversation.buyer_id then conversation.seller_id else conversation.buyer_id end;
  insert into public.offers(listing_id,conversation_id,from_user_id,to_user_id,kind,cash_amount,expires_at)
  values(conversation.listing_id,p_conversation_id,actor,recipient,p_kind,p_cash_amount,now()+interval '48 hours')
  returning id into result;
  insert into public.offer_items(offer_id,offered_listing_id) select result,i from unnest(p_offered_listing_ids) i;
  insert into public.messages(conversation_id,from_user_id,to_user_id,body,type,offer_id)
  values(p_conversation_id,actor,recipient,'Sent an offer','offer',result);
  update public.conversations set last_message='Sent an offer',updated_at=now() where id=p_conversation_id;
  return result;
end $$;

-- Bug: marking a listing sold directly (not via an accepted offer) left
-- every other pending offer on it stuck at "pending" for up to 48h, with
-- Accept/Decline buttons that silently fail. A trigger on the listing
-- itself is the root fix: it also covers finish_reservation's own sold
-- path and any future caller, not just today's two.
create function app_private.decline_offers_on_sold() returns trigger
language plpgsql security definer set search_path = '' as $$
declare sibling record;
begin
  if new.status='sold' and old.status is distinct from 'sold' then
    for sibling in
      select id, conversation_id, from_user_id
      from public.offers where listing_id=new.id and status='pending'
    loop
      update public.offers set status='declined' where id=sibling.id;
      insert into public.messages(conversation_id,from_user_id,to_user_id,body,type)
      values(sibling.conversation_id,new.seller_id,sibling.from_user_id,'This item was sold','system');
      update public.conversations set last_message='This item was sold',updated_at=now()
        where id=sibling.conversation_id;
    end loop;
  end if;
  return new;
end $$;
revoke all on function app_private.decline_offers_on_sold() from public, anon, authenticated;

drop trigger if exists listings_decline_offers_on_sold on public.listings;
create trigger listings_decline_offers_on_sold
after update of status on public.listings
for each row execute function app_private.decline_offers_on_sold();

notify pgrst, 'reload schema';
