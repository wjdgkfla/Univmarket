-- In-app report review for moderators. An admin is a verified, active member
-- whose profiles.role is 'admin' (set only by the project owner; clients
-- cannot write role). Admins moderate their own university only, and every
-- action is written to admin_activity.

-- The caller's university, or an error unless they are an active admin.
create function app_private.admin_university() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare
  actor text := auth.uid()::text;
  university uuid := app_private.member_university(actor);
begin
  if university is null or not exists (
    select 1 from public.profiles where id = actor and role = 'admin'
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  return university;
end $$;

-- Open reports about students at the admin's university, newest first.
create function app_private.admin_open_reports() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  university uuid := app_private.admin_university();
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id,
      'reason', r.reason,
      'notes', r.notes,
      'created_at', r.created_at,
      'reporter_name', reporter.display_name,
      'reported_user_id', reported.id,
      'reported_user_name', reported.display_name,
      'reported_user_state', reported.account_state,
      'open_reports_on_user', (
        select count(*) from public.reports o
        where o.reported_user_id = r.reported_user_id and o.status = 'open'),
      'listing_id', l.id,
      'listing_title', l.title,
      'listing_hidden', l.moderation_state <> 'visible' or l.deleted_at is not null
    ) order by r.created_at desc)
    from public.reports r
    join public.profiles reported on reported.id = r.reported_user_id
    join public.profiles reporter on reporter.id = r.reporter_id
    left join public.listings l on l.id = r.listing_id
    where r.status = 'open' and reported.university_id = university
  ), '[]'::jsonb);
end $$;

-- Closes one report with an outcome:
--   dismiss       no action
--   hide_listing  hide the reported listing; closes every open report on it
--   suspend_user  lock the student out and hide their listings; closes every
--                 open report about them
create function app_private.admin_resolve_report(p_report_id text, p_action text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor text := auth.uid()::text;
  university uuid := app_private.admin_university();
  report public.reports;
begin
  if p_action is null or p_action not in ('dismiss', 'hide_listing', 'suspend_user') then
    raise exception 'Invalid action' using errcode = '22023';
  end if;
  select r.* into report from public.reports r
  join public.profiles p on p.id = r.reported_user_id
  where r.id = p_report_id and r.status = 'open' and p.university_id = university
  for update of r;
  if report.id is null then
    raise exception 'Report unavailable' using errcode = '42501';
  end if;

  if p_action = 'dismiss' then
    update public.reports set status = 'resolved' where id = report.id;
  elsif p_action = 'hide_listing' then
    if report.listing_id is null then
      raise exception 'Invalid action' using errcode = '22023';
    end if;
    update public.listings set moderation_state = 'hidden' where id = report.listing_id;
    update public.reports set status = 'resolved'
      where listing_id = report.listing_id and status = 'open';
  else
    if report.reported_user_id = actor or exists (
      select 1 from public.profiles
      where id = report.reported_user_id and role = 'admin'
    ) then
      raise exception 'Admins cannot be suspended here' using errcode = '42501';
    end if;
    update public.profiles set account_state = 'suspended'
      where id = report.reported_user_id and account_state = 'active';
    update public.listings set moderation_state = 'hidden'
      where seller_id = report.reported_user_id and moderation_state = 'visible';
    update public.reports set status = 'resolved'
      where reported_user_id = report.reported_user_id and status = 'open';
  end if;

  insert into public.admin_activity (actor_user_id, action, target_type, target_id, notes)
  values (actor, p_action, 'report', report.id,
    case p_action
      when 'hide_listing' then 'listing ' || report.listing_id
      when 'suspend_user' then 'user ' || report.reported_user_id
    end);
end $$;

create function public.admin_open_reports() returns jsonb
language sql stable security invoker set search_path = '' as $$
  select app_private.admin_open_reports()
$$;
create function public.admin_resolve_report(p_report_id text, p_action text) returns void
language sql security invoker set search_path = '' as $$
  select app_private.admin_resolve_report(p_report_id, p_action)
$$;

revoke all on function app_private.admin_university() from public, anon, authenticated;
revoke all on function app_private.admin_open_reports() from public, anon, authenticated;
revoke all on function app_private.admin_resolve_report(text, text) from public, anon, authenticated;
grant execute on function app_private.admin_open_reports(),
  app_private.admin_resolve_report(text, text) to authenticated, service_role;
grant execute on function app_private.admin_university() to service_role;
revoke execute on function public.admin_open_reports(),
  public.admin_resolve_report(text, text) from public, anon;
grant execute on function public.admin_open_reports(),
  public.admin_resolve_report(text, text) to authenticated;
notify pgrst, 'reload schema';
