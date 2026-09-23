-- Disposable CI database only; every fixture and write is rolled back.
begin;
create temp table checks(label text, passed boolean, actual text);
grant all on checks to authenticated, anon;
create function pg_temp.probe(label text, statement text, expected text default 'allowed')
returns void language plpgsql as $$
declare result text;
begin
 begin execute statement;
 raise exception using errcode='ZX001', message='rollback successful probe';
 exception when others then result:=sqlstate; end;
 insert into checks values(label,case when expected='allowed' then result='ZX001' else result=expected end,result);
end $$;
create function pg_temp.check(label text, passed boolean) returns void
language sql as $$ insert into checks values(label, passed, passed::text) $$;

-- University A: admin 1, reporter 2, sellers 3 and 4. University B: admin 5, student 6.
insert into universities(id,slug,name,short_name,active) values
('10000000-0000-0000-0000-000000000001','test-a','Test A','A',true),
('10000000-0000-0000-0000-000000000002','test-b','Test B','B',true);
insert into university_domains values
('a.test','10000000-0000-0000-0000-000000000001'),('b.test','10000000-0000-0000-0000-000000000002');
insert into campuses(id,university_id,slug,name) values
('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','main','Main A'),
('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','main','Main B');
insert into auth.users(id,email,email_confirmed_at,is_anonymous)
select ('20000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
 'user'||n||case when n in (5,6) then '@b.test' else '@a.test' end, now(), false
from generate_series(1,6) n;
insert into profiles(id,university_id,home_campus_id,display_name,role)
select '20000000-0000-0000-0000-'||lpad(n::text,12,'0'),
 ('10000000-0000-0000-0000-'||lpad(case when n in (5,6) then '2' else '1' end,12,'0'))::uuid,
 ('30000000-0000-0000-0000-'||lpad(case when n in (5,6) then '2' else '1' end,12,'0'))::uuid,
 'Student '||n, case when n in (1,5) then 'admin' else 'student' end
from generate_series(1,6) n;
insert into listings(id,seller_id,university_id,campus_id,title,description) values
('scam','20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Cheap laptop','Too good to be true.'),
('other','20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Desk chair','A normal desk chair.'),
('fine','20000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Bike lock','A sturdy bike lock.');
insert into reports(id,reporter_id,reported_user_id,listing_id,reason,notes) values
('r-scam','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000003','scam','scam','Asked for a deposit'),
('r-scam-2','20000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000003','scam','scam',null),
('r-user','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000003',null,'harassment',null),
('r-fine','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000004','fine','spam',null),
('r-admin','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001',null,'other',null),
('r-b','20000000-0000-0000-0000-000000000006','20000000-0000-0000-0000-000000000005',null,'spam',null);

set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
select pg_temp.probe('students cannot list reports',$q$select admin_open_reports()$q$,'42501');
select pg_temp.probe('students cannot resolve reports',$q$select admin_resolve_report('r-fine','dismiss')$q$,'42501');

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select pg_temp.check('admin sees only their university''s open reports',
 (select array_agg(x->>'id' order by x->>'id') from jsonb_array_elements(admin_open_reports()) x)
 = array['r-admin','r-fine','r-scam','r-scam-2','r-user']);
select pg_temp.check('queue shows reporter, listing and repeat count',
 (select x->>'reporter_name'='Student 2' and x->>'listing_title'='Cheap laptop'
   and (x->>'open_reports_on_user')::int=3 and x->>'notes'='Asked for a deposit'
  from jsonb_array_elements(admin_open_reports()) x where x->>'id'='r-scam'));
select pg_temp.probe('another university''s report is off limits',
$q$select admin_resolve_report('r-b','dismiss')$q$,'42501');
select pg_temp.probe('unknown action rejected',$q$select admin_resolve_report('r-fine','delete')$q$,'22023');
select pg_temp.probe('hiding needs a reported listing',$q$select admin_resolve_report('r-user','hide_listing')$q$,'22023');
select pg_temp.probe('admins cannot suspend themselves',
$q$select admin_resolve_report('r-admin','suspend_user')$q$,'42501');

select admin_resolve_report('r-fine','dismiss');
select pg_temp.check('dismiss closes the report and changes nothing else',
 (select status from reports where id='r-fine')='resolved'
 and (select moderation_state from listings where id='fine')='visible');

select admin_resolve_report('r-scam','hide_listing');
select pg_temp.check('hide takes the listing off the market',
 (select moderation_state from listings where id='scam')='hidden');
select pg_temp.check('hide closes every report on that listing',
 (select count(*) from reports where listing_id='scam' and status='open')=0
 and (select status from reports where id='r-user')='open');
select pg_temp.probe('a closed report cannot be acted on again',
$q$select admin_resolve_report('r-scam','dismiss')$q$,'42501');

select admin_resolve_report('r-user','suspend_user');
select pg_temp.check('suspend locks the student out',
 (select account_state from profiles where id='20000000-0000-0000-0000-000000000003')='suspended');
select pg_temp.check('suspend hides all their listings',
 not exists(select 1 from listings where seller_id='20000000-0000-0000-0000-000000000003' and moderation_state='visible'));
select pg_temp.check('queue now shows only the admin report',
 (select array_agg(x->>'id') from jsonb_array_elements(admin_open_reports()) x)=array['r-admin']);

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000003';
select pg_temp.probe('suspended student can no longer enter the market',$q$select ensure_profile()$q$,'42501');

set local role anon;
select pg_temp.probe('anonymous cannot list reports',$q$select admin_open_reports()$q$,'42501');

reset role;
-- admin_activity has no client policies, so read the log as the owner.
select pg_temp.check('every action is logged',
 (select array_agg(action order by created_at, action) from admin_activity
  where actor_user_id='20000000-0000-0000-0000-000000000001')
 = array['dismiss','hide_listing','suspend_user']);
table checks;
do $$ declare failures text; begin
select string_agg(label||' ['||actual||']', E'\n') into failures from checks where not passed;
if failures is not null then raise exception E'Admin report review regressions:\n%',failures; end if;
end $$;
select count(*)||' admin report review checks passed' as result from checks;
rollback;
