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

-- University A: reporter 1, seller 2. University B: student 3.
insert into universities(id,slug,name,short_name,active) values
('10000000-0000-0000-0000-000000000001','test-a','Test A','A',true),
('10000000-0000-0000-0000-000000000002','test-b','Test B','B',true);
insert into university_domains values
('a.test','10000000-0000-0000-0000-000000000001'),('b.test','10000000-0000-0000-0000-000000000002');
insert into campuses(id,university_id,slug,name) values
('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','main','Main A'),
('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','main','Main B');
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
('20000000-0000-0000-0000-000000000001','reporter@a.test',now(),false),
('20000000-0000-0000-0000-000000000002','seller@a.test',now(),false),
('20000000-0000-0000-0000-000000000003','other@b.test',now(),false);
insert into profiles(id,university_id,home_campus_id,display_name) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Reporter'),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Seller'),
('20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','Other');
insert into listings(id,seller_id,university_id,campus_id,title,description) values
('item','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Desk lamp','A working desk lamp.'),
('own','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Bike lock','A sturdy bike lock.');

set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select pg_temp.probe('direct report insert no longer allowed',
$q$insert into reports(reporter_id,reported_user_id,reason) values(auth.uid()::text,'20000000-0000-0000-0000-000000000002','spam')$q$,'42501');
select report_user('20000000-0000-0000-0000-000000000002','item','scam','Asked for payment upfront');
select report_user('20000000-0000-0000-0000-000000000002','item','scam',null);
select pg_temp.check('classmate listing report is filed once, repeats ignored',
 (select count(*) from reports where listing_id='item')=1);
select pg_temp.check('reporter sees their own report',
 (select reason from reports where listing_id='item')='scam');
select pg_temp.probe('user report without a listing allowed',
$q$select report_user('20000000-0000-0000-0000-000000000002',null,'harassment')$q$);
select pg_temp.probe('cannot report yourself',
$q$select report_user('20000000-0000-0000-0000-000000000001',null,'spam')$q$,'42501');
select pg_temp.probe('cannot report another university',
$q$select report_user('20000000-0000-0000-0000-000000000003',null,'spam')$q$,'42501');
select pg_temp.probe('listing must belong to the reported student',
$q$select report_user('20000000-0000-0000-0000-000000000002','own','spam')$q$,'42501');
select pg_temp.probe('unknown reason rejected',
$q$select report_user('20000000-0000-0000-0000-000000000002',null,'dislike')$q$,'22023');
select pg_temp.probe('oversized notes rejected',
$q$select report_user('20000000-0000-0000-0000-000000000002',null,'other',repeat('a',1001))$q$,'22023');

-- Blocking: own rows only, and it ends contact both ways.
insert into blocks(blocker_id,blocked_id) values(auth.uid()::text,'20000000-0000-0000-0000-000000000002');
select pg_temp.check('blocker sees own block',(select count(*) from blocks)=1);
select pg_temp.probe('cannot block on someone else''s behalf',
$q$insert into blocks(blocker_id,blocked_id) values('20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001')$q$,'42501');
select pg_temp.probe('blocked seller cannot be messaged',
$q$select start_conversation('item')$q$,'42501');
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
select pg_temp.check('blocked student cannot see who blocked them',(select count(*) from blocks)=0);
select pg_temp.probe('blocked student cannot message the blocker',
$q$select start_conversation('own')$q$,'42501');
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
delete from blocks where blocked_id='20000000-0000-0000-0000-000000000002';
select pg_temp.probe('unblocking restores contact',$q$select start_conversation('item')$q$);

reset role;
table checks;
do $$ declare failures text; begin
select string_agg(label||' ['||actual||']', E'\n') into failures from checks where not passed;
if failures is not null then raise exception E'Report and block regressions:\n%',failures; end if;
end $$;
select count(*)||' report and block checks passed' as result from checks;
rollback;
