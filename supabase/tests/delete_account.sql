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

-- Seller 1, leaving student 2 and classmate 3, all at university A.
insert into universities(id,slug,name,short_name,active) values
('10000000-0000-0000-0000-000000000001','test-a','Test A','A',true);
insert into university_domains values ('a.test','10000000-0000-0000-0000-000000000001');
insert into campuses(id,university_id,slug,name) values
('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','main','Main A');
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
('20000000-0000-0000-0000-000000000001','seller@a.test',now(),false),
('20000000-0000-0000-0000-000000000002','leaving@a.test',now(),false),
('20000000-0000-0000-0000-000000000003','classmate@a.test',now(),false);
insert into profiles(id,university_id,home_campus_id,display_name,bio) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Seller',null),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Leaving Student','Personal bio'),
('20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Classmate',null);
insert into listings(id,seller_id,university_id,campus_id,title,description) values
('reserved','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Desk lamp','A working desk lamp.'),
('pending','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Bike lock','A sturdy bike lock.'),
('own','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Mini fridge','A small dorm fridge.');

-- Student 2 buys "reserved" (accepted), offers on "pending", saves and blocks.
create temp table flow(listing_id text, conversation_id text, offer_id text);
grant all on flow to authenticated;
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
insert into flow(listing_id,conversation_id) select id,start_conversation(id) from (values('reserved'),('pending')) v(id);
update flow set offer_id=send_offer(conversation_id,'cash',10,'{}');
select create_message(conversation_id,'Is it still available?') from flow where listing_id='reserved';
insert into favorites(user_id,listing_id) values(auth.uid()::text,'pending');
insert into blocks(blocker_id,blocked_id) values(auth.uid()::text,'20000000-0000-0000-0000-000000000003');
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select respond_to_offer(offer_id,'accept') from flow where listing_id='reserved';

set local role anon;
select pg_temp.probe('anonymous callers cannot delete an account',$q$select delete_my_account()$q$,'42501');

set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
select delete_my_account();

reset role;
select pg_temp.check('sign-in removed',
 not exists(select 1 from auth.users where id='20000000-0000-0000-0000-000000000002'));
select pg_temp.check('other accounts untouched',
 (select count(*) from auth.users where id in ('20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000003'))=2);
select pg_temp.check('profile anonymized',
 (select display_name='Deleted student' and bio is null and account_state='deleted' and deleted_at is not null
  from profiles where id='20000000-0000-0000-0000-000000000002'));
select pg_temp.check('deleted profile hidden from other students',
 not exists(select 1 from public_profiles where id='20000000-0000-0000-0000-000000000002'));
select pg_temp.check('own listings removed from the market',
 (select deleted_at is not null from listings where id='own'));
select pg_temp.check('reservation cancelled and item back on sale',
 (select status from listings where id='reserved')='available'
 and (select status from transactions where listing_id='reserved')='cancelled'
 and not exists(select 1 from transaction_listings where listing_id='reserved' and is_active));
select pg_temp.check('pending offer withdrawn',
 (select status from offers where id=(select offer_id from flow where listing_id='pending'))='withdrawn');
select pg_temp.check('personal data removed',
 not exists(select 1 from favorites where user_id='20000000-0000-0000-0000-000000000002')
 and not exists(select 1 from blocks where blocker_id='20000000-0000-0000-0000-000000000002'));
select pg_temp.check('chat history kept for the other student',
 exists(select 1 from messages where from_user_id='20000000-0000-0000-0000-000000000002' and body='Is it still available?'));

-- The seller keeps a working market and a readable history.
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select pg_temp.check('seller still reads the conversation',
 exists(select 1 from messages where body='Is it still available?'));
select pg_temp.probe('seller can edit the relisted item',
$q$do $b$ begin update listings set title='Desk lamp again' where id='reserved'; if not found then raise exception 'not editable'; end if; end $b$;$q$);
select pg_temp.probe('seller cannot keep messaging a deleted account',
$q$select create_message((select conversation_id from flow where listing_id='reserved'),'Hello?')$q$,'42501');

-- A lingering token for the deleted account no longer works.
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
select pg_temp.probe('deleted account cannot delete twice',$q$select delete_my_account()$q$,'42501');
select pg_temp.probe('deleted account cannot re-enter the market',$q$select ensure_profile()$q$,'42501');

reset role;
table checks;
do $$ declare failures text; begin
select string_agg(label||' ['||actual||']', E'\n') into failures from checks where not passed;
if failures is not null then raise exception E'Account deletion regressions:\n%',failures; end if;
end $$;
select count(*)||' account deletion checks passed' as result from checks;
rollback;
