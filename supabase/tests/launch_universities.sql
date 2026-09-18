-- Verify approved domains produce the correct university and campus.
begin;
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 ('70000000-0000-0000-0000-000000000001','ci@gmu.edu',now(),false),
 ('70000000-0000-0000-0000-000000000002','ci@gwu.edu',now(),false),
 ('70000000-0000-0000-0000-000000000003','ci@gmu.edu.attacker.test',now(),false);
set local role authenticated;
set local request.jwt.claim.sub='70000000-0000-0000-0000-000000000001';
do $$ declare p public.profiles; begin
 p:=public.ensure_profile();
 if not exists(select 1 from public.universities u join public.campuses c on c.university_id=u.id
   where u.id=p.university_id and u.slug='george-mason' and c.id=p.home_campus_id and c.name='Fairfax') then
  raise exception 'GMU assignment failed'; end if;
 if (public.ensure_profile()).id<>p.id then raise exception 'Profile creation not idempotent'; end if;
end $$;
set local request.jwt.claim.sub='70000000-0000-0000-0000-000000000002';
do $$ declare p public.profiles; begin
 p:=public.ensure_profile();
 if not exists(select 1 from public.universities u join public.campuses c on c.university_id=u.id
   where u.id=p.university_id and u.slug='george-washington' and c.id=p.home_campus_id and c.name='Foggy Bottom') then
  raise exception 'GWU assignment failed'; end if;
end $$;
set local request.jwt.claim.sub='70000000-0000-0000-0000-000000000003';
do $$ begin
 begin
  perform public.ensure_profile();
  raise exception 'Lookalike domain gained access';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
 if exists(select 1 from public.universities
   where active and slug not in ('george-mason','george-washington')) then
  raise exception 'Only GMU and GWU may be active at launch'; end if;
end $$;
rollback;
select 'GMU and GWU onboarding checks passed' as result;
