-- User-approved launch schools and default campuses; no users or pickup places.
insert into public.universities(slug,name,short_name,active) values
 ('george-mason','George Mason University','GMU',true),
 ('george-washington','George Washington University','GWU',true)
on conflict(slug) do nothing;

-- Do not silently move an existing domain to a different university.
do $$
declare school record; university uuid;
begin
 for school in select * from (values
  ('george-mason','gmu.edu','Fairfax'),
  ('george-washington','gwu.edu','Foggy Bottom')
 ) as schools(slug,domain,campus_name) loop
  select id into strict university from public.universities where slug=school.slug;
  if exists(select 1 from public.university_domains
    where lower(domain)=school.domain and university_id<>university) then
    raise exception 'Domain % already belongs to a different university',school.domain;
  end if;
  insert into public.university_domains(domain,university_id)
   values(school.domain,university) on conflict(domain) do nothing;
  insert into public.campuses(university_id,slug,name,active)
   values(university,'main',school.campus_name,true) on conflict(university_id,slug) do nothing;
 end loop;
end $$;
