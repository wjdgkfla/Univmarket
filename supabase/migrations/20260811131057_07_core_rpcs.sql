-- Blocking check helper, used by every message/offer write path (fixes the
-- blueprint's "block enforced on one endpoint, bypassable via another" —
-- there is only one path here, this function, called from both RPCs below.
create function is_blocked(p_a text, p_b text) returns bool
  language sql stable security definer as
  $$ select exists (
       select 1 from blocks
       where (blocker_id = p_a and blocked_id = p_b)
          or (blocker_id = p_b and blocked_id = p_a)
     ) $$;

-- Finds the (buyer=actor, seller=listing.seller) conversation for a listing,
-- creating it if it doesn't exist yet. Mirrors the Flutter demo's
-- conversationForListing so the client swap is a near 1:1 signature match.
create function start_conversation(p_listing_id text) returns text
  language plpgsql security definer as $$
declare
  v_actor text := auth.uid()::text;
  v_seller text;
  v_conv_id text;
begin
  if not is_active_user(v_actor) then
    raise exception 'account not active';
  end if;

  select seller_id into v_seller from listings where id = p_listing_id and deleted_at is null;
  if v_seller is null then
    raise exception 'listing not found';
  end if;
  if v_seller = v_actor then
    raise exception 'cannot message yourself about your own listing';
  end if;
  if is_blocked(v_actor, v_seller) then
    raise exception 'messaging unavailable';
  end if;

  select id into v_conv_id from conversations where listing_id = p_listing_id and buyer_id = v_actor;
  if v_conv_id is not null then
    return v_conv_id;
  end if;

  insert into conversations (listing_id, buyer_id, seller_id)
  values (p_listing_id, v_actor, v_seller)
  returning id into v_conv_id;
  return v_conv_id;
end;
$$;

-- Sole write path for plain text messages — fixes the blueprint's per-route
-- duplicated authorization by having exactly one path, ever.
create function create_message(p_conversation_id text, p_body text) returns text
  language plpgsql security definer as $$
declare
  v_actor text := auth.uid()::text;
  v_buyer text; v_seller text; v_to text; v_msg_id text;
begin
  if not is_active_user(v_actor) then raise exception 'account not active'; end if;

  select buyer_id, seller_id into v_buyer, v_seller from conversations where id = p_conversation_id;
  if v_buyer is null then raise exception 'conversation not found'; end if;
  if v_actor not in (v_buyer, v_seller) then raise exception 'not a participant'; end if;

  v_to := case when v_actor = v_buyer then v_seller else v_buyer end;
  if is_blocked(v_actor, v_to) then raise exception 'messaging unavailable'; end if;

  insert into messages (conversation_id, from_user_id, to_user_id, body, type)
  values (p_conversation_id, v_actor, v_to, p_body, 'text')
  returning id into v_msg_id;

  update conversations set last_message = p_body, updated_at = now() where id = p_conversation_id;
  return v_msg_id;
end;
$$;

-- Creates a cash/trade offer + its offer_items + a rendering message.
create function send_offer(
  p_conversation_id text,
  p_kind text,
  p_cash_amount numeric default 0,
  p_offered_listing_ids text[] default '{}'
) returns text
  language plpgsql security definer as $$
declare
  v_actor text := auth.uid()::text;
  v_buyer text; v_seller text; v_listing_id text; v_to text; v_offer_id text; v_item text;
begin
  if not is_active_user(v_actor) then raise exception 'account not active'; end if;
  if p_kind not in ('cash','trade','trade_plus_cash') then raise exception 'invalid offer kind'; end if;
  if array_length(p_offered_listing_ids, 1) > 3 then raise exception 'max 3 offered items'; end if;

  select buyer_id, seller_id, listing_id into v_buyer, v_seller, v_listing_id
  from conversations where id = p_conversation_id;
  if v_buyer is null then raise exception 'conversation not found'; end if;
  if v_actor not in (v_buyer, v_seller) then raise exception 'not a participant'; end if;

  v_to := case when v_actor = v_buyer then v_seller else v_buyer end;
  if is_blocked(v_actor, v_to) then raise exception 'messaging unavailable'; end if;

  if p_kind in ('trade', 'trade_plus_cash') then
    foreach v_item in array p_offered_listing_ids loop
      if not exists (
        select 1 from listings where id = v_item and seller_id = v_actor and status = 'available'
      ) then
        raise exception 'offered item % is not your own available listing', v_item;
      end if;
    end loop;
  end if;

  insert into offers (listing_id, conversation_id, from_user_id, to_user_id, kind, cash_amount, expires_at)
  values (v_listing_id, p_conversation_id, v_actor, v_to, p_kind, p_cash_amount, now() + interval '48 hours')
  returning id into v_offer_id;

  foreach v_item in array p_offered_listing_ids loop
    insert into offer_items (offer_id, offered_listing_id) values (v_offer_id, v_item);
  end loop;

  insert into messages (conversation_id, from_user_id, to_user_id, body, type, offer_id)
  values (p_conversation_id, v_actor, v_to, 'Sent an offer', 'offer', v_offer_id);

  update conversations set last_message = 'Sent an offer', updated_at = now() where id = p_conversation_id;
  return v_offer_id;
end;
$$;

-- Accept/decline/withdraw. Acceptance is always keyed on the offer's
-- RECIPIENT, never a fixed role — this is the single most severe defect
-- found in the blueprint audit (a seller-only accept_offer broke buyer-side
-- counteroffer acceptance). Accepting locks the offer + listing, declines
-- competing pending offers on the same listing, and reserves it via a
-- transaction — same atomic shape as the blueprint's correct pattern.
create function respond_to_offer(p_offer_id text, p_action text) returns void
  language plpgsql security definer as $$
declare
  v_actor text := auth.uid()::text;
  v_offer offers%rowtype;
  v_txn_id text;
begin
  if p_action not in ('accept','decline','withdraw') then raise exception 'invalid action'; end if;

  select * into v_offer from offers where id = p_offer_id for update;
  if v_offer.id is null then raise exception 'offer not found'; end if;
  if v_offer.status <> 'pending' then raise exception 'offer is no longer pending'; end if;

  if p_action = 'accept' then
    if v_actor <> v_offer.to_user_id then raise exception 'only the offer recipient can accept it'; end if;

    perform 1 from listings where id = v_offer.listing_id for update;

    update offers set status = 'declined'
    where listing_id = v_offer.listing_id and status = 'pending' and id <> v_offer.id;

    insert into transactions (listing_id, offer_id, buyer_id, seller_id, kind, agreed_price)
    values (
      v_offer.listing_id, v_offer.id, v_offer.from_user_id, v_offer.to_user_id,
      case when v_offer.kind = 'cash' then 'sale' else 'trade' end,
      v_offer.cash_amount
    ) returning id into v_txn_id;

    insert into transaction_listings (transaction_id, listing_id, role)
    values (v_txn_id, v_offer.listing_id, 'target');

    insert into transaction_listings (transaction_id, listing_id, role)
    select v_txn_id, offered_listing_id, 'offered' from offer_items where offer_id = v_offer.id;

    update listings set status = 'reserved'
    where id in (
      select listing_id from transaction_listings where transaction_id = v_txn_id
    );

    update offers set status = 'accepted' where id = v_offer.id;

    insert into messages (conversation_id, from_user_id, to_user_id, body, type)
    values (v_offer.conversation_id, v_actor, v_offer.from_user_id, 'Offer accepted', 'system');

  elsif p_action = 'decline' then
    if v_actor <> v_offer.to_user_id then raise exception 'only the offer recipient can decline it'; end if;
    update offers set status = 'declined' where id = v_offer.id;
    insert into messages (conversation_id, from_user_id, to_user_id, body, type)
    values (v_offer.conversation_id, v_actor, v_offer.from_user_id, 'Offer declined', 'system');

  else -- withdraw
    if v_actor <> v_offer.from_user_id then raise exception 'only the offerer can withdraw it'; end if;
    update offers set status = 'withdrawn' where id = v_offer.id;
    insert into messages (conversation_id, from_user_id, to_user_id, body, type)
    values (v_offer.conversation_id, v_actor, v_offer.to_user_id, 'Offer withdrawn', 'system');
  end if;
end;
$$;
