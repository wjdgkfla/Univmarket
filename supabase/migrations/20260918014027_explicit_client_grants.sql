-- Explicit grants make the recovered schema work with auto exposure disabled.
-- RLS continues to decide which rows each client may access.
grant usage on schema public to anon, authenticated, service_role;
grant select on public.universities, public.campuses, public.pickup_zones to anon, authenticated;
grant select on public.profiles, public.public_profiles, public.listings,
  public.conversations, public.messages, public.offers, public.offer_items,
  public.transactions, public.transaction_listings, public.ratings,
  public.reports, public.blocks, public.favorites, public.saved_searches,
  public.price_watches, public.notifications, public.notification_preferences,
  public.device_push_tokens to authenticated;
grant update (display_name, bio) on public.profiles to authenticated;
grant insert, update on public.listings to authenticated;
grant insert on public.reports to authenticated;
grant insert, delete on public.blocks to authenticated;
grant insert, update, delete on public.favorites, public.saved_searches,
  public.price_watches, public.notification_preferences, public.device_push_tokens to authenticated;
grant update (is_read) on public.notifications to authenticated;
grant execute on function public.is_active_user(text), public.is_blocked(text,text),
  public.increment_view_count(text), public.ensure_profile(text),
  public.start_conversation(text), public.create_message(text,text),
  public.send_offer(text,text,numeric,text[]), public.respond_to_offer(text,text) to authenticated;
grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;
notify pgrst, 'reload schema';
