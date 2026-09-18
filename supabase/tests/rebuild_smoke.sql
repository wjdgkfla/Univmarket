-- Run only against an isolated rebuild. All fixtures are rolled back.
begin;
insert into public.universities (id,slug,name,short_name,active)
values ('10000000-0000-0000-0000-000000000001','ci-school','CI School','CI',true);
insert into public.profiles (id,university_id,display_name)
values ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','CI Owner'),
       ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','CI Outsider');
set local role authenticated;
set local request.jwt.claim.sub = '20000000-0000-0000-0000-000000000001';
do $test$
declare changed integer;
begin
  if (select count(*) from public.profiles) <> 1 then
    raise exception 'Profile owner isolation failed';
  end if;
  update public.profiles set display_name='Edited by owner'
    where id='20000000-0000-0000-0000-000000000001';
  get diagnostics changed = row_count;
  if changed <> 1 then raise exception 'Owner could not edit display name'; end if;
  update public.profiles set display_name='Unauthorized edit'
    where id='20000000-0000-0000-0000-000000000002';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'Owner edited another profile'; end if;
  begin
    update public.profiles set role='admin'
      where id='20000000-0000-0000-0000-000000000001';
    raise exception 'Owner escalated profile role';
  exception when insufficient_privilege then null;
  end;
  if (public.ensure_profile()).display_name <> 'Edited by owner' then
    raise exception 'Existing-profile RPC no longer works';
  end if;
end $test$;
reset role;
do $test$
begin
  if exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' and not c.relrowsecurity
  ) then raise exception 'Public table missing RLS'; end if;
  if has_function_privilege('anon','public.ensure_profile(text)','EXECUTE')
     or has_function_privilege('anon','public.create_message(text,text)','EXECUTE')
     or has_function_privilege('anon','public.respond_to_offer(text,text)','EXECUTE') then
    raise exception 'Anonymous client can call a private RPC';
  end if;
  if not has_column_privilege('authenticated','public.listings','title','INSERT')
     or not has_table_privilege('authenticated','public.messages','SELECT') then
    raise exception 'Required marketplace API grants missing';
  end if;
end $test$;
rollback;
select 'rebuild smoke checks passed' as result;
