-- Verification for the owner-authorized preview seed. Every write rolls back.
begin;
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 ('71000000-0000-0000-0000-000000000001','sample-access-a@gmu.edu',now(),false),
 ('71000000-0000-0000-0000-000000000002','sample-access-b@gwu.edu',now(),false);
set local role authenticated;
do $$
declare scenario record;
begin
 for scenario in select * from (values
   ('71000000-0000-0000-0000-000000000001','george-mason'),
   ('71000000-0000-0000-0000-000000000002','george-washington')
 ) x(actor,school) loop
   perform set_config('request.jwt.claim.sub',scenario.actor,true);
   perform public.ensure_profile();
   if (select count(*) from public.listings where seller_id='sample-seller-' || scenario.school) <> 4 then
     raise exception 'Own school samples not visible';
   end if;
   if exists(select 1 from public.listings where seller_id like 'sample-seller-%' and seller_id <> 'sample-seller-' || scenario.school) then
     raise exception 'Other university samples leaked';
   end if;
   begin
     perform public.start_conversation('sample-' || scenario.school || '-1');
     raise exception 'Sample seller allowed contact';
   exception when insufficient_privilege then null;
   end;
 end loop;
end $$;
set local role anon;
do $$ begin
 begin
   if exists(select 1 from public.listings) then raise exception 'Unauthenticated listing access'; end if;
 exception when insufficient_privilege then null;
 end;
end $$;
reset role;
do $$ begin
 if exists(select 1 from public.profiles p join auth.users a on a.id::text=p.id where p.id like 'sample-seller-%') then
   raise exception 'Sample seller has a login account';
 end if;
end $$;
rollback;
select 'Four samples per school, university isolation, no sample contact, no anonymous access: passed' as result;
