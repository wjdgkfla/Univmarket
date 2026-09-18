-- Clients can read the minimum build before sign-in but can never change it.
begin;
create function pg_temp.assert_read_only(who text) returns void language plpgsql as $$
declare n integer;
begin
 if (select min_build from public.app_config) is null then
  raise exception '% cannot read the minimum build', who; end if;
 begin
  update public.app_config set min_build = 999;
  get diagnostics n = row_count;
  if n <> 0 then raise exception '% changed the minimum build', who; end if;
 exception when insufficient_privilege then null; end;
 begin
  insert into public.app_config(id, min_build) values (true, 999);
  raise exception '% inserted app config', who;
 exception when insufficient_privilege or unique_violation then null; end;
end $$;
grant execute on function pg_temp.assert_read_only(text) to anon, authenticated;
set local role anon;
select pg_temp.assert_read_only('Anonymous client');
set local role authenticated;
select pg_temp.assert_read_only('Signed-in client');
reset role;
rollback;
select 'App config read-only checks passed' as result;
