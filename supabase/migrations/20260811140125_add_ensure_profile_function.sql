create function ensure_profile(p_display_name text default null) returns profiles
language plpgsql security definer set search_path = public as $$
declare
  v_uid text := auth.uid()::text;
  v_univ_id uuid;
  v_campus_id uuid;
  v_profile profiles;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_profile from profiles where id = v_uid;
  if found then
    return v_profile;
  end if;

  select id into v_univ_id from universities where slug = 'fenwick';
  select id into v_campus_id from campuses where slug = 'main' and university_id = v_univ_id;

  insert into profiles (id, university_id, home_campus_id, display_name)
  values (v_uid, v_univ_id, v_campus_id, coalesce(p_display_name, 'Student ' || substr(v_uid, 1, 6)))
  returning * into v_profile;

  return v_profile;
end;
$$;

revoke execute on function ensure_profile(text) from anon;
