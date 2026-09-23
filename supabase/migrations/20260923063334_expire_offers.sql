-- Offers carry a 48-hour deadline (send_offer), and respond_to_offer already
-- refuses expired ones, but nothing moved them out of 'pending'. Expire them
-- on a schedule so both sides see the real state.
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;

create function app_private.expire_offers() returns integer
language sql security definer set search_path = '' as $$
  with expired as (
    update public.offers set status = 'expired'
    where status = 'pending' and expires_at <= now()
    returning 1
  )
  select count(*)::integer from expired
$$;
revoke all on function app_private.expire_offers() from public, anon, authenticated;
grant execute on function app_private.expire_offers() to service_role;

-- Every 10 minutes; re-running this migration replaces the job by name.
select cron.schedule('expire-offers', '*/10 * * * *', 'select app_private.expire_offers()');
