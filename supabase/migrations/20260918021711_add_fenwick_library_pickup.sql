-- User-approved first pickup location. Other locations are deferred.
-- Fenwick Library belongs to GMU Fairfax, not the legacy Fenwick university.
-- Reference: https://library.gmu.edu/locations/fenwick
do $$
declare fairfax_campus uuid;
begin
 select c.id into strict fairfax_campus
 from public.campuses c join public.universities u on u.id=c.university_id
 where u.slug='george-mason' and c.slug='main' and c.name='Fairfax'
   and u.active and c.active;
 insert into public.pickup_zones(campus_id,slug,name,safety_note,active)
 values(fairfax_campus,'fenwick-library','Fenwick Library',
   'Agree on an exact meeting point. Check posted opening hours and follow library rules.',true)
 on conflict(campus_id,slug) do nothing;
end $$;
