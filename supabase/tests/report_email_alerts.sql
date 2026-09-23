-- Disposable CI database only; every fixture and write is rolled back.
begin;
create temp table checks(label text, passed boolean, actual text);
grant all on checks to authenticated, anon, service_role;
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

-- University A: admin 1, reporter 2, seller 3, suspended admin 4.
-- University B: admin 5.
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
 'user'||n||case when n=5 then '@b.test' else '@a.test' end, now(), false
from generate_series(1,5) n;
insert into profiles(id,university_id,home_campus_id,display_name,role,account_state)
select '20000000-0000-0000-0000-'||lpad(n::text,12,'0'),
 ('10000000-0000-0000-0000-'||lpad(case when n=5 then '2' else '1' end,12,'0'))::uuid,
 ('30000000-0000-0000-0000-'||lpad(case when n=5 then '2' else '1' end,12,'0'))::uuid,
 'Student '||n, case when n in (1,4,5) then 'admin' else 'student' end,
 case when n=4 then 'suspended' else 'active' end
from generate_series(1,5) n;
insert into listings(id,seller_id,university_id,campus_id,title,description) values
('item','20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Cheap laptop','Too good to be true.');

create temp table token as
select decrypted_secret as value from vault.decrypted_secrets where name='report_email_token';
grant select on token to service_role;
select pg_temp.check('a random report email token was generated',
 (select length(value) from token) = 72);
create temp table queued as select count(*) as n from net.http_request_queue;

-- Without a project URL (local and CI), filing a report queues nothing.
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
select report_user('20000000-0000-0000-0000-000000000003','item','scam','Asked for a deposit');
reset role;
select pg_temp.check('no project URL, no email call',
 (select count(*) from net.http_request_queue) = (select n from queued));

-- With a project URL, each new report queues exactly one call.
select vault.create_secret('https://example.test','project_url');
set local role authenticated;
select report_user('20000000-0000-0000-0000-000000000003',null,'harassment',null);
select report_user('20000000-0000-0000-0000-000000000003',null,'harassment',null);
reset role;
select pg_temp.check('a new report queues one call to notify-new-report',
 (select count(*) from net.http_request_queue) = (select n from queued) + 1
 and exists(select 1 from net.http_request_queue
   where url = 'https://example.test/functions/v1/notify-new-report'
     and headers->>'x-report-token' = (select value from token)));

-- Details for the email, service key plus token only.
set local role anon;
select pg_temp.probe('anonymous cannot read report details',
$q$select report_email_details((select value from token),'x')$q$,'42501');
set local role authenticated;
select pg_temp.probe('students cannot read report details',
$q$select report_email_details((select value from token),'x')$q$,'42501');
set local role service_role;
select pg_temp.probe('service key without the token is refused',
$q$select report_email_details('wrong-token','x')$q$,'42501');
create temp table details as
select report_email_details((select value from token), r.id) as d
from reports r where r.listing_id='item';
select pg_temp.check('email carries the report, school, people and listing',
 (select d->>'reason'='scam' and d->>'school'='Test A' and d->>'listing_title'='Cheap laptop'
   and d->>'reported_user_name'='Student 3' and d->>'reporter_name'='Student 2'
   and d->>'notes'='Asked for a deposit' from details));
select pg_temp.check('only active admins at that school are emailed',
 (select d->'admin_emails' from details) = '["user1@a.test"]'::jsonb);
select pg_temp.check('an unknown report returns nothing',
 report_email_details((select value from token), 'missing') is null);

reset role;
table checks;
do $$ declare failures text; begin
select string_agg(label||' ['||actual||']', E'\n') into failures from checks where not passed;
if failures is not null then raise exception E'Report email regressions:\n%',failures; end if;
end $$;
select count(*)||' report email checks passed' as result from checks;
rollback;
