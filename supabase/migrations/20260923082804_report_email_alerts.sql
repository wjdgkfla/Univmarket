-- Email moderators when a report is filed. An after-insert trigger queues a
-- pg_net call to the notify-new-report Edge Function, which sends through
-- Gmail. pg_net sends only after the transaction commits, so a rolled-back
-- report sends nothing, and report_user's ON CONFLICT DO NOTHING means
-- repeat reports never insert and never email.

-- Random per environment; only this database and its trigger know it.
select vault.create_secret(
  gen_random_uuid()::text || gen_random_uuid()::text,
  'report_email_token',
  'Authorizes notify-new-report calls from the reports trigger'
);

-- Everything the email needs about one open report, plus the email
-- addresses of active admins at the reported student's university.
create function app_private.report_email_details(p_token text, p_report_id text)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_token is null or not exists (
    select 1 from vault.decrypted_secrets
    where name = 'report_email_token' and decrypted_secret = p_token
  ) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  return (
    select jsonb_build_object(
      'reason', r.reason,
      'notes', r.notes,
      'created_at', r.created_at,
      'school', u.name,
      'reported_user_name', reported.display_name,
      'reporter_name', reporter.display_name,
      'listing_title', l.title,
      'admin_emails', coalesce((
        select jsonb_agg(a.email order by a.email)
        from public.profiles p
        join auth.users a on a.id::text = p.id
        where p.role = 'admin' and p.university_id = reported.university_id
          and app_private.member_university(p.id) = reported.university_id
      ), '[]'::jsonb)
    )
    from public.reports r
    join public.profiles reported on reported.id = r.reported_user_id
    join public.profiles reporter on reporter.id = r.reporter_id
    join public.universities u on u.id = reported.university_id
    left join public.listings l on l.id = r.listing_id
    where r.id = p_report_id and r.status = 'open'
  );
end $$;

create function public.report_email_details(p_token text, p_report_id text)
returns jsonb
language sql stable security invoker set search_path = '' as $$
  select app_private.report_email_details(p_token, p_report_id)
$$;

revoke all on function app_private.report_email_details(text, text) from public, anon, authenticated;
grant execute on function app_private.report_email_details(text, text) to service_role;
revoke all on function public.report_email_details(text, text) from public, anon, authenticated;
grant execute on function public.report_email_details(text, text) to service_role;

-- Needs the project's API URL in Vault as 'project_url' (set for the hosted
-- project by supabase/operations/configure_photo_cleanup.sql). Without it
-- nothing is queued, so local and CI rebuilds never call production.
create function app_private.queue_report_email() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform net.http_post(
    url := url.decrypted_secret || '/functions/v1/notify-new-report',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-report-token', token.decrypted_secret),
    body := jsonb_build_object('report_id', new.id))
  from vault.decrypted_secrets url, vault.decrypted_secrets token
  where url.name = 'project_url' and token.name = 'report_email_token';
  return null;
end $$;
revoke all on function app_private.queue_report_email() from public, anon, authenticated;

create trigger reports_email_moderators
after insert on public.reports
for each row execute function app_private.queue_report_email();
notify pgrst, 'reload schema';
