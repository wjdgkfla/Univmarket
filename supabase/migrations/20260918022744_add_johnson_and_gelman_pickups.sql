-- Additional user-approved pickup locations; preserve existing pickup choices.
-- https://studentcenters.gmu.edu/the-johnson-center/
-- https://calendar.gwu.edu/gelman_library
do $$
declare location record; target_campus uuid;
begin
 for location in select * from (values
  ('george-mason','Fairfax','johnson-center','Johnson Center'),
  ('george-washington','Foggy Bottom','gelman-library','Gelman Library')
 ) as locations(university_slug,campus_name,pickup_slug,pickup_name) loop
  select c.id into strict target_campus
  from public.campuses c join public.universities u on u.id=c.university_id
  where u.slug=location.university_slug and c.slug='main'
    and c.name=location.campus_name and u.active and c.active;
  insert into public.pickup_zones(campus_id,slug,name,safety_note,active)
  values(target_campus,location.pickup_slug,location.pickup_name,
    'Agree on an exact meeting point. Check posted opening hours and follow building access rules.',true)
  on conflict(campus_id,slug) do nothing;
 end loop;
end $$;
