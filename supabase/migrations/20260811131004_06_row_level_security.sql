-- Enable RLS everywhere the client can reach.
alter table universities enable row level security;
alter table university_domains enable row level security;
alter table campuses enable row level security;
alter table pickup_zones enable row level security;
alter table university_waitlist enable row level security;
alter table profiles enable row level security;
alter table listings enable row level security;
alter table conversations enable row level security;
alter table messages enable row level security;
alter table offers enable row level security;
alter table offer_items enable row level security;
alter table transactions enable row level security;
alter table transaction_listings enable row level security;
alter table ratings enable row level security;
alter table reports enable row level security;
alter table blocks enable row level security;
alter table favorites enable row level security;
alter table saved_searches enable row level security;
alter table price_watches enable row level security;
alter table notifications enable row level security;
alter table notification_preferences enable row level security;
alter table device_push_tokens enable row level security;
alter table outbox_events enable row level security;
alter table admin_activity enable row level security;
alter table analytics_events enable row level security;

-- Reference/geo tables: public read where active, no client writes at all.
create policy universities_read on universities for select using (active);
create policy campuses_read on campuses for select using (active);
create policy pickup_zones_read on pickup_zones for select using (active);
-- university_domains / university_waitlist: no client policies at all (service-role/Edge Function only).

-- Profiles: public-safe subset via a view; full row only to owner.
create view public_profiles as
  select id, display_name, profile_image_url, reputation_score,
         completed_transaction_count, joined_at, university_id, home_campus_id
  from profiles where account_state != 'deleted';
grant select on public_profiles to authenticated, anon;

create policy profiles_owner_select on profiles for select using (auth.uid()::text = id);
create policy profiles_owner_update on profiles for update using (auth.uid()::text = id);
create policy profiles_owner_insert on profiles for insert with check (auth.uid()::text = id);

-- Listings: scoped to the viewer's own university, or the seller's own rows regardless of state.
create policy listings_select on listings for select using (
  (moderation_state = 'visible' and deleted_at is null
   and university_id = (select university_id from profiles where id = auth.uid()::text))
  or seller_id = auth.uid()::text
);
create policy listings_insert on listings for insert with check (
  seller_id = auth.uid()::text and is_active_user(auth.uid()::text)
);
create policy listings_update_owner on listings for update using (
  seller_id = auth.uid()::text
  and not exists (
    select 1 from transaction_listings tl join transactions t on t.id = tl.transaction_id
    where tl.listing_id = listings.id and t.status in ('reserved','meetup_scheduled')
  )
);
-- No delete policy: soft-delete only, via the update policy (sets deleted_at).

-- Conversations/messages/offers/offer_items/transactions/transaction_listings/ratings:
-- SELECT scoped to participants. NO insert/update/delete grants to `authenticated` — all writes
-- go through SECURITY DEFINER RPCs (migration 07), which is what makes the blueprint's
-- authorization-duplication and blocking-bypass defects structurally impossible here.
create policy conversations_participants on conversations for select using (
  auth.uid()::text in (buyer_id, seller_id)
);
create policy messages_participants on messages for select using (
  auth.uid()::text in (from_user_id, to_user_id)
);
create policy offers_participants on offers for select using (
  auth.uid()::text in (from_user_id, to_user_id)
);
create policy offer_items_participants on offer_items for select using (
  exists (
    select 1 from offers o where o.id = offer_items.offer_id
    and auth.uid()::text in (o.from_user_id, o.to_user_id)
  )
);
create policy transactions_participants on transactions for select using (
  auth.uid()::text in (buyer_id, seller_id)
);
create policy transaction_listings_participants on transaction_listings for select using (
  exists (
    select 1 from transactions t where t.id = transaction_listings.transaction_id
    and auth.uid()::text in (t.buyer_id, t.seller_id)
  )
);
create policy ratings_participants on ratings for select using (
  auth.uid()::text in (reviewer_id, reviewee_id)
);

-- Reports/blocks: the actor can see and create their own; no update/delete from the client.
create policy reports_own_select on reports for select using (auth.uid()::text = reporter_id);
create policy reports_own_insert on reports for insert with check (auth.uid()::text = reporter_id);
create policy blocks_own_select on blocks for select using (auth.uid()::text = blocker_id);
create policy blocks_own_insert on blocks for insert with check (auth.uid()::text = blocker_id);
create policy blocks_own_delete on blocks for delete using (auth.uid()::text = blocker_id);

-- Favorites/saved_searches/price_watches/notifications/notification_preferences/device_push_tokens:
-- standard owner-only CRUD — simple enough to allow direct table access safely (no RPC needed).
create policy favorites_owner_all on favorites for all
  using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);
create policy saved_searches_owner_all on saved_searches for all
  using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);
create policy price_watches_owner_all on price_watches for all
  using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);
create policy notifications_owner_select on notifications for select using (auth.uid()::text = user_id);
create policy notifications_owner_update on notifications for update using (auth.uid()::text = user_id);
create policy notification_preferences_owner_all on notification_preferences for all
  using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);
create policy device_push_tokens_owner_all on device_push_tokens for all
  using (auth.uid()::text = user_id) with check (auth.uid()::text = user_id);

-- admin_activity/analytics_events/outbox_events: no client policies — service-role only.

-- Realtime: safe to enable now that real participant-scoped policies exist (not deny-all).
alter publication supabase_realtime add table messages, offers, transactions;
