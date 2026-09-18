-- Require verified university membership at the database boundary.
-- No existing identities, memberships, or marketplace records are rewritten.
create schema if not exists app_private;
revoke all on schema app_private from public, anon;
grant usage on schema app_private to authenticated, service_role;

-- Internal lookup: never trust JWT user_metadata, or a client-selected university.
create function app_private.verified_domain_university(p_uid text) returns uuid
language sql stable set search_path = '' as $$
  select (array_agg(d.university_id))[1]
  from auth.users a
  join public.university_domains d on lower(d.domain)=lower(split_part(a.email,'@',2))
  join public.universities u on u.id=d.university_id and u.active
  where a.id::text=p_uid and a.email_confirmed_at is not null
    and not coalesce(a.is_anonymous,false) and a.deleted_at is null
    and (a.banned_until is null or a.banned_until <= now())
  having count(*)=1
$$;

create function app_private.member_university(p_uid text) returns uuid
language sql stable set search_path = '' as $$
  select p.university_id from public.profiles p
  join public.campuses c on c.id=p.home_campus_id and c.university_id=p.university_id and c.active
  where p.id=p_uid and p.account_state='active' and p.deleted_at is null
    and p.university_id=app_private.verified_domain_university(p_uid)
$$;

-- RLS can call this without gaining read access to auth.users or other profiles.
create function app_private.current_university() returns uuid
language sql stable security definer set search_path = '' as $$
  select app_private.member_university(auth.uid()::text)
$$;

create function app_private.blocked(p_a text,p_b text) returns boolean
language sql stable set search_path = '' as $$
  select exists(select 1 from public.blocks
    where (blocker_id=p_a and blocked_id=p_b) or (blocker_id=p_b and blocked_id=p_a))
$$;

create function app_private.ensure_profile(p_display_name text default null) returns public.profiles
language plpgsql security definer set search_path = '' as $$
declare
  actor text:=auth.uid()::text;
  university uuid;
  campus uuid;
  profile public.profiles;
begin
  university:=app_private.verified_domain_university(actor);
  if university is null then
    raise exception 'Confirm an email from an approved university' using errcode='42501';
  end if;
  select * into profile from public.profiles where id=actor;
  if found then
    if app_private.member_university(actor) is null then
      raise exception 'University access requires review' using errcode='42501';
    end if;
    return profile;
  end if;
  -- Only choose an explicitly configured main campus, or the sole active campus.
  select id into campus from public.campuses where university_id=university and active and slug='main';
  if campus is null then
    select (array_agg(id))[1] into campus from public.campuses
    where university_id=university and active having count(*)=1;
  end if;
  if campus is null then
    raise exception 'University campus setup is required' using errcode='42501';
  end if;
  insert into public.profiles(id,university_id,home_campus_id,display_name)
  values(actor,university,campus,coalesce(nullif(btrim(p_display_name),''),'Student '||substr(actor,1,6)))
  on conflict(id) do nothing;
  select * into profile from public.profiles where id=actor;
  if app_private.member_university(actor) is null then
    raise exception 'University access requires review' using errcode='42501';
  end if;
  return profile;
end $$;

create function app_private.authorized_conversation(p_id text) returns public.conversations
language plpgsql set search_path = '' as $$
declare
  actor text:=auth.uid()::text;
  university uuid:=app_private.member_university(actor);
  conversation public.conversations;
begin
  select * into conversation from public.conversations where id=p_id;
  if university is null or conversation.id is null or not conversation.is_active
    or actor not in (conversation.buyer_id,conversation.seller_id)
    or app_private.member_university(conversation.buyer_id) is distinct from university
    or app_private.member_university(conversation.seller_id) is distinct from university
    or app_private.blocked(conversation.buyer_id,conversation.seller_id)
    or not exists(select 1 from public.listings l where l.id=conversation.listing_id
      and l.seller_id=conversation.seller_id and l.university_id=university
      and l.moderation_state='visible' and l.deleted_at is null)
  then raise exception 'Conversation unavailable' using errcode='42501'; end if;
  return conversation;
end $$;

create function app_private.start_conversation(p_listing_id text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  actor text:=auth.uid()::text;
  university uuid:=app_private.member_university(actor);
  listing public.listings;
  result text;
begin
  select * into listing from public.listings where id=p_listing_id;
  if university is null or listing.id is null or listing.seller_id=actor
    or listing.university_id is distinct from university
    or app_private.member_university(listing.seller_id) is distinct from university
    or listing.status<>'available' or listing.moderation_state<>'visible' or listing.deleted_at is not null
    or app_private.blocked(actor,listing.seller_id)
  then raise exception 'Listing unavailable' using errcode='42501'; end if;
  insert into public.conversations(listing_id,buyer_id,seller_id)
  values(p_listing_id,actor,listing.seller_id) on conflict(listing_id,buyer_id) do nothing;
  select id into result from public.conversations where listing_id=p_listing_id and buyer_id=actor;
  perform app_private.authorized_conversation(result);
  return result;
end $$;

create function app_private.create_message(p_conversation_id text,p_body text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  actor text:=auth.uid()::text;
  conversation public.conversations;
  recipient text;
  result text;
begin
  conversation:=app_private.authorized_conversation(p_conversation_id);
  if p_body is null or length(btrim(p_body)) not between 1 and 2000 then
    raise exception 'Message must be between 1 and 2000 characters' using errcode='22023';
  end if;
  recipient:=case when actor=conversation.buyer_id then conversation.seller_id else conversation.buyer_id end;
  insert into public.messages(conversation_id,from_user_id,to_user_id,body,type)
  values(p_conversation_id,actor,recipient,btrim(p_body),'text') returning id into result;
  update public.conversations set last_message=btrim(p_body),updated_at=now() where id=p_conversation_id;
  return result;
end $$;

create function app_private.send_offer(p_conversation_id text,p_kind text,
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

create function app_private.respond_to_offer(p_offer_id text,p_action text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor text:=auth.uid()::text;
  offer public.offers;
  conversation public.conversations;
  transaction_id text;
  recipient text;
  affected text[];
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
    update public.offers set status='declined' where listing_id=offer.listing_id and status='pending' and id<>offer.id;
    update public.offers set status='accepted' where id=offer.id;
  else
    update public.offers set status=case when p_action='decline' then 'declined' else 'withdrawn' end where id=offer.id;
  end if;
  recipient:=case when actor=offer.from_user_id then offer.to_user_id else offer.from_user_id end;
  insert into public.messages(conversation_id,from_user_id,to_user_id,body,type)
  values(offer.conversation_id,actor,recipient,
    case p_action when 'accept' then 'Offer accepted' when 'decline' then 'Offer declined' else 'Offer withdrawn' end,'system');
end $$;

create function app_private.increment_view_count(p_listing_id text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.listings set view_count=view_count+1 where id=p_listing_id
    and university_id=app_private.member_university(auth.uid()::text)
    and app_private.member_university(seller_id)=university_id
    and not app_private.blocked(auth.uid()::text,seller_id)
    and moderation_state='visible' and deleted_at is null;
  if not found then raise exception 'Listing unavailable' using errcode='42501'; end if;
end $$;

-- Public endpoints keep the Flutter signatures but run as the invoker.
-- Only the narrowly granted private implementations hold elevated privileges.
create or replace function public.ensure_profile(p_display_name text default null) returns public.profiles
language sql security invoker set search_path='' as $$ select app_private.ensure_profile(p_display_name) $$;
create or replace function public.start_conversation(p_listing_id text) returns text
language sql security invoker set search_path='' as $$ select app_private.start_conversation(p_listing_id) $$;
create or replace function public.create_message(p_conversation_id text,p_body text) returns text
language sql security invoker set search_path='' as $$ select app_private.create_message(p_conversation_id,p_body) $$;
create or replace function public.send_offer(p_conversation_id text,p_kind text,p_cash_amount numeric default 0,p_offered_listing_ids text[] default '{}') returns text
language sql security invoker set search_path='' as $$ select app_private.send_offer(p_conversation_id,p_kind,p_cash_amount,p_offered_listing_ids) $$;
create or replace function public.respond_to_offer(p_offer_id text,p_action text) returns void
language sql security invoker set search_path='' as $$ select app_private.respond_to_offer(p_offer_id,p_action) $$;
create or replace function public.increment_view_count(p_listing_id text) returns void
language sql security invoker set search_path='' as $$ select app_private.increment_view_count(p_listing_id) $$;
create or replace function public.is_active_user(uid text) returns boolean
language sql stable security invoker set search_path='' as $$
 select coalesce(uid=auth.uid()::text and app_private.current_university() is not null,false)
$$;
-- A caller cannot use the old helper to probe unrelated users' block relationships.
create function app_private.my_block_status(p_a text,p_b text) returns boolean
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or auth.uid()::text not in (p_a,p_b) or p_a is null or p_b is null then
   raise exception 'Not authorized' using errcode='42501'; end if;
 return app_private.blocked(p_a,p_b);
end $$;
create or replace function public.is_blocked(p_a text,p_b text) returns boolean
language sql stable security invoker set search_path='' as $$ select app_private.my_block_status(p_a,p_b) $$;

revoke all on all functions in schema app_private from public,anon,authenticated;
grant execute on function app_private.current_university(),app_private.ensure_profile(text),
 app_private.start_conversation(text),app_private.create_message(text,text),
 app_private.send_offer(text,text,numeric,text[]),app_private.respond_to_offer(text,text),
 app_private.increment_view_count(text),app_private.my_block_status(text,text) to authenticated;
grant execute on all functions in schema app_private to service_role;
revoke execute on function public.ensure_profile(text),public.start_conversation(text),
 public.create_message(text,text),public.send_offer(text,text,numeric,text[]),
 public.respond_to_offer(text,text),public.increment_view_count(text),
 public.is_active_user(text),public.is_blocked(text,text) from public,anon;
grant execute on function public.ensure_profile(text),public.start_conversation(text),
 public.create_message(text,text),public.send_offer(text,text,numeric,text[]),
 public.respond_to_offer(text,text),public.increment_view_count(text),
 public.is_active_user(text),public.is_blocked(text,text) to authenticated;

-- Deny stale, anonymous, deleted, suspended, or mismatched memberships in all client data.
do $$
declare table_name text;
begin
 foreach table_name in array array['profiles','listings','conversations','messages','offers','offer_items',
 'transactions','transaction_listings','ratings','reports','blocks','favorites','saved_searches',
 'price_watches','notifications','notification_preferences','device_push_tokens'] loop
 execute format('create policy verified_membership on public.%I as restrictive for all to authenticated
 using ((select app_private.current_university()) is not null)
 with check ((select app_private.current_university()) is not null)',table_name);
 end loop;
end $$;

drop policy listings_insert on public.listings;
drop policy listings_update_owner on public.listings;
create policy listings_insert on public.listings for insert to authenticated with check (
 seller_id=auth.uid()::text and university_id=(select app_private.current_university())
 and status='available' and moderation_state='visible' and deleted_at is null
 and exists(select 1 from public.campuses c where c.id=campus_id and c.university_id=listings.university_id and c.active)
 and (pickup_zone_id is null or exists(select 1 from public.pickup_zones z where z.id=pickup_zone_id and z.campus_id=listings.campus_id and z.active))
);
create policy listings_update_owner on public.listings for update to authenticated using (
 seller_id=auth.uid()::text and university_id=(select app_private.current_university())
 and status='available' and moderation_state='visible' and deleted_at is null
 and not exists(select 1 from public.transaction_listings t where t.listing_id=listings.id and t.is_active)
) with check (
 seller_id=auth.uid()::text and university_id=(select app_private.current_university())
 and status in ('available','sold') and moderation_state='visible'
 and exists(select 1 from public.campuses c where c.id=campus_id and c.university_id=listings.university_id and c.active)
 and (pickup_zone_id is null or exists(select 1 from public.pickup_zones z where z.id=pickup_zone_id and z.campus_id=listings.campus_id and z.active))
);
-- Remove historical table-wide grants, then grant only client-editable fields.
revoke insert,update on public.listings from public,anon,authenticated;
grant insert(seller_id,university_id,campus_id,pickup_zone_id,title,description,price,category,condition,
 listing_kind,accepts_trades,image_urls,cover_image_url,tags,course_code,professor_name,edition,bundle_notes)
 on public.listings to authenticated;
grant update(pickup_zone_id,title,description,price,category,condition,listing_kind,accepts_trades,
 image_urls,cover_image_url,tags,course_code,professor_name,edition,bundle_notes,status,deleted_at)
 on public.listings to authenticated;
notify pgrst,'reload schema';
