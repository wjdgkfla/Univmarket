-- Cheap poll for the moderator badge and "new report" alert: the number of
-- open reports at the admin's university. Same admin check as the queue.
-- plpgsql so the admin check always runs first: inside a WHERE clause the
-- planner could skip it when no rows exist and answer 0 to a non-admin.
create function app_private.admin_open_report_count() returns integer
language plpgsql stable security definer set search_path = '' as $$
declare
  university uuid := app_private.admin_university();
begin
  return (
    select count(*)::integer
    from public.reports r
    join public.profiles reported on reported.id = r.reported_user_id
    where r.status = 'open' and reported.university_id = university
  );
end $$;

create function public.admin_open_report_count() returns integer
language sql stable security invoker set search_path = '' as $$
  select app_private.admin_open_report_count()
$$;

revoke all on function app_private.admin_open_report_count() from public, anon, authenticated;
grant execute on function app_private.admin_open_report_count() to authenticated, service_role;
revoke execute on function public.admin_open_report_count() from public, anon;
grant execute on function public.admin_open_report_count() to authenticated;
notify pgrst, 'reload schema';
