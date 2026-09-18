-- Listing creation must accept each new campus pickup and reject the other campus.
begin;
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 ('72000000-0000-0000-0000-000000000001','new-pickup@gmu.edu',now(),false),
 ('72000000-0000-0000-0000-000000000002','new-pickup@gwu.edu',now(),false);
set local role authenticated;
do $$
declare scenario record; p public.profiles; zone uuid; foreign_zone uuid; saved public.listings;
begin
 for scenario in select * from (values
  ('72000000-0000-0000-0000-000000000001','johnson-center','Johnson Center','gelman-library'),
  ('72000000-0000-0000-0000-000000000002','gelman-library','Gelman Library','johnson-center')
 ) as cases(actor,own_slug,own_name,foreign_slug) loop
  perform set_config('request.jwt.claim.sub',scenario.actor,true);
  p:=public.ensure_profile();
  select id into zone from public.pickup_zones where campus_id=p.home_campus_id
   and slug=scenario.own_slug and name=scenario.own_name and active;
  if zone is null then raise exception 'Missing campus pickup: %',scenario.own_name; end if;
  insert into public.listings(seller_id,university_id,campus_id,pickup_zone_id,title,description,price)
  values(p.id,p.university_id,p.home_campus_id,zone,'Pickup test','Configured campus pickup test',10)
  returning * into saved;
  if saved.pickup_zone_id is distinct from zone then raise exception 'Selected pickup not saved'; end if;
  select id into strict foreign_zone from public.pickup_zones where slug=scenario.foreign_slug and active;
  begin
   insert into public.listings(seller_id,university_id,campus_id,pickup_zone_id,title,description,price)
   values(p.id,p.university_id,p.home_campus_id,foreign_zone,'Cross-campus test','Must reject foreign pickup',10);
   raise exception 'Cross-university pickup accepted';
  exception when insufficient_privilege then null; end;
 end loop;
end $$;
reset role;
rollback;
select 'Johnson Center and Gelman Library pickup checks passed' as result;
