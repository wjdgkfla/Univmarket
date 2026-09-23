-- Disposable CI database only; every fixture and write is rolled back.
-- Covers 20260923120000_chat_survives_listing_state.sql: an existing
-- conversation must survive its listing going reserved/sold/hidden/deleted,
-- while a brand-new conversation still respects listing availability.
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

insert into universities(id,slug,name,short_name,active) values
('10000000-0000-0000-0000-000000000001','test-a','Test A','A',true),
('10000000-0000-0000-0000-000000000002','test-b','Test B','B',true);
insert into university_domains values
('a.test','10000000-0000-0000-0000-000000000001'),('b.test','10000000-0000-0000-0000-000000000002');
insert into campuses(id,university_id,slug,name) values
('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','main','Main A'),
('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','main','Main B');
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
('20000000-0000-0000-0000-000000000001','buyer@a.test',now(),false),
('20000000-0000-0000-0000-000000000002','seller@a.test',now(),false),
('20000000-0000-0000-0000-000000000003','other-buyer@a.test',now(),false),
('20000000-0000-0000-0000-000000000004','foreign@b.test',now(),false);
insert into profiles(id,university_id,home_campus_id,display_name) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Buyer'),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Seller'),
('20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Other buyer'),
('20000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','Foreign');
insert into listings(id,seller_id,university_id,campus_id,title,description) values
('target','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Target','A reserved item'),
('hidden-target','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Hidden','A hidden item');
insert into conversations(id,listing_id,buyer_id,seller_id) values
('chat','target','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002'),
('hidden-chat','hidden-target','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002'),
('cross-chat','target','20000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000002');
-- Fixture setup only (as table owner, RLS not yet active for this session).
update listings set status='reserved' where id='target';
update listings set moderation_state='hidden' where id='hidden-target';

set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';

-- Bug #2: "Message seller" on your own reserved/sold listing's thread must
-- reopen it, not re-run the availability check.
select pg_temp.probe(
  'reopening chat about a reserved listing succeeds',
  $q$select start_conversation('target')$q$);
select pg_temp.check(
  'reopening returns the existing conversation, not a duplicate',
  (select count(*) from conversations where listing_id='target' and buyer_id='20000000-0000-0000-0000-000000000001')=1);

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000003';
select pg_temp.probe(
  'a brand-new conversation on a reserved listing is still refused',
  $q$select start_conversation('target')$q$,'42501');

-- Bug #3: marking a thread read must not depend on the listing at all.
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select pg_temp.probe(
  'marking a reserved listing''s chat read succeeds',
  $q$select mark_conversation_read('chat')$q$);
select pg_temp.check(
  'the read marker actually moved',
  (select buyer_last_read_at is not null from conversations where id='chat'));
select pg_temp.probe(
  'marking a hidden listing''s chat read still succeeds',
  $q$select mark_conversation_read('hidden-chat')$q$);

-- Existing protections must still hold: a non-participant, a blocked
-- counterparty, and a different university are all still denied.
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000004';
select pg_temp.probe(
  'a non-participant cannot mark someone else''s chat read',
  $q$select mark_conversation_read('chat')$q$,'42501');

reset role;
insert into blocks(blocker_id,blocked_id) values
('20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002');
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select pg_temp.probe(
  'a blocked counterparty''s chat still cannot be marked read',
  $q$select mark_conversation_read('chat')$q$,'42501');

table checks;
do $$ declare failures text; begin
select string_agg(label||' ['||actual||']', E'\n') into failures from checks where not passed;
if failures is not null then raise exception E'Chat availability regressions:\n%',failures; end if;
end $$;
select count(*)||' chat availability checks passed' as result from checks;
rollback;
