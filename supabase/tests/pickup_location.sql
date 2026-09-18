-- Exercise the configured pickup through the same table writes as the app.
begin;
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 ('71000000-0000-0000-0000-000000000001','pickup-test@gmu.edu',now(),false),
 ('71000000-0000-0000-0000-000000000002','pickup-test@gwu.edu',now(),false);
set local role authenticated;
set local request.jwt.claim.sub='71000000-0000-0000-0000-000000000001';
do $$
declare p public.profiles; zone uuid; saved public.listings;
begin
 p:=public.ensure_profile();
 select id into zone from public.pickup_zones
 where campus_id=p.home_campus_id and slug='fenwick-library' and name='Fenwick Library' and active;
 if zone is null then raise exception 'Fenwick Library missing from GMU Fairfax pickup locations'; end if;
 insert into public.listings(seller_id,university_id,campus_id,pickup_zone_id,title,description,price)
 values(p.id,p.university_id,p.home_campus_id,zone,'Test textbook','Pickup at Fenwick Library',10)
 returning * into saved;
 if saved.pickup_zone_id is distinct from zone then raise exception 'Listing did not retain selected pickup'; end if;
end $$;
set local request.jwt.claim.sub='71000000-0000-0000-0000-000000000002';
do $$
declare p public.profiles; zone uuid;
begin
 p:=public.ensure_profile();
 select z.id into strict zone from public.pickup_zones z
 join public.campuses c on c.id=z.campus_id join public.universities u on u.id=c.university_id
 where u.slug='george-mason' and c.slug='main' and z.slug='fenwick-library';
 begin
  insert into public.listings(seller_id,university_id,campus_id,pickup_zone_id,title,description,price)
  values(p.id,p.university_id,p.home_campus_id,zone,'Cross-campus test','Must not allow another university pickup',10);
  raise exception 'GWU listing accepted GMU pickup location';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
select 'Fenwick pickup selection and university isolation passed' as result;
