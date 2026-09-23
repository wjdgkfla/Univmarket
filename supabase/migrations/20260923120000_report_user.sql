-- Reports feed moderation, so they must name a real classmate, carry a known
-- reason, and not be spammed. Route them through one checked RPC instead of
-- the direct insert grant.
alter table public.reports
  add constraint reports_reason_known
    check (reason in ('prohibited','scam','harassment','spam','other')),
  add constraint reports_notes_length
    check (notes is null or length(notes) <= 1000);

-- One open report per reporter, person and listing; repeats are no-ops.
create unique index reports_one_open_per_target
  on public.reports (reporter_id, reported_user_id, coalesce(listing_id, ''))
  where status = 'open';
create index if not exists reports_status_idx on public.reports (status, created_at);

create function app_private.report_user(
  p_reported_user_id text, p_listing_id text, p_reason text, p_notes text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor text := auth.uid()::text;
  university uuid := app_private.member_university(actor);
begin
  if university is null then
    raise exception 'University access required' using errcode = '42501';
  end if;
  if p_reported_user_id is null or p_reported_user_id = actor
    or app_private.member_university(p_reported_user_id) is distinct from university
    or (p_listing_id is not null and not exists (
      select 1 from public.listings l
      where l.id = p_listing_id and l.seller_id = p_reported_user_id
        and l.university_id = university))
  then
    raise exception 'Report unavailable' using errcode = '42501';
  end if;
  if p_reason is null or p_reason not in ('prohibited','scam','harassment','spam','other')
    or length(p_notes) > 1000
  then
    raise exception 'Invalid report' using errcode = '22023';
  end if;
  insert into public.reports (reporter_id, reported_user_id, listing_id, reason, notes)
  values (actor, p_reported_user_id, p_listing_id, p_reason, nullif(btrim(p_notes), ''))
  on conflict (reporter_id, reported_user_id, coalesce(listing_id, ''))
    where status = 'open' do nothing;
end $$;

create function public.report_user(
  p_reported_user_id text, p_listing_id text, p_reason text, p_notes text default null)
returns void
language sql security invoker set search_path = '' as $$
  select app_private.report_user(p_reported_user_id, p_listing_id, p_reason, p_notes)
$$;

revoke insert on public.reports from authenticated;
revoke all on function app_private.report_user(text, text, text, text) from public, anon, authenticated;
grant execute on function app_private.report_user(text, text, text, text) to authenticated, service_role;
revoke execute on function public.report_user(text, text, text, text) from public, anon;
grant execute on function public.report_user(text, text, text, text) to authenticated;
notify pgrst, 'reload schema';
