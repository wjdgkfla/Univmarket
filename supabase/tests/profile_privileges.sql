begin;
set local role authenticated;
do $test$
declare field text;
begin
  foreach field in array array['id','university_id','home_campus_id','role','account_state','reputation_score','completed_transaction_count','joined_at','last_active_at','deleted_at'] loop
    begin
      execute format('update public.profiles set %1$I = %1$I where false', field);
      raise exception 'Client can update protected profile field: %', field;
    exception when insufficient_privilege then null;
    end;
  end loop;
  begin
    update public.public_profiles set reputation_score = reputation_score where false;
    raise exception 'Client can mutate profile view';
  exception when insufficient_privilege then null;
  end;
  if has_table_privilege(current_user, 'public.profiles', 'INSERT') then
    raise exception 'Client can create arbitrary profiles';
  end if;
  if exists (select 1 from information_schema.role_table_grants
    where table_schema = 'public' and grantee in ('anon','authenticated')
      and privilege_type in ('TRUNCATE','TRIGGER','REFERENCES')) then
    raise exception 'Client has administrative table privileges';
  end if;
  -- Must still be permitted at the column level. No rows are modified.
  update public.profiles set display_name = display_name, bio = bio where false;
end
$test$;
rollback;
select 'profile privilege regression passed' as result;
