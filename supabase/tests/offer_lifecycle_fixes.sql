-- Disposable CI database only; every fixture and write is rolled back.
-- Covers 20260923130000_offer_lifecycle_fixes.sql.
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
('10000000-0000-0000-0000-000000000001','test-a','Test A','A',true);
insert into university_domains values ('a.test','10000000-0000-0000-0000-000000000001');
insert into campuses(id,university_id,slug,name) values
('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','main','Main A');
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
('20000000-0000-0000-0000-000000000001','buyer1@a.test',now(),false),
('20000000-0000-0000-0000-000000000002','seller@a.test',now(),false),
('20000000-0000-0000-0000-000000000003','buyer2@a.test',now(),false),
('20000000-0000-0000-0000-000000000004','buyer4@a.test',now(),false);
insert into profiles(id,university_id,home_campus_id,display_name) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Buyer 1'),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Seller'),
('20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Buyer 2'),
('20000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Buyer 4');
insert into listings(id,seller_id,university_id,campus_id,title,description) values
('target','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Target','Two competing offers'),
('target2','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Target 2','Sold directly, no accepted offer');
insert into conversations(id,listing_id,buyer_id,seller_id) values
('chat1','target','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002'),
('chat2','target','20000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002'),
('chat4','target2','20000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000002');
insert into offers(id,listing_id,conversation_id,from_user_id,to_user_id,kind,cash_amount,expires_at) values
('offer1','target','chat1','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','cash',10,now()+interval '1 day'),
('offer2','target','chat2','20000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002','cash',8,now()+interval '1 day'),
('offer4','target2','chat4','20000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000002','cash',5,now()+interval '1 day');

set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select pg_temp.probe(
  'a second pending offer from the same buyer on the same listing is rejected',
  $q$select send_offer('chat1','cash',5,'{}')$q$,'22023');

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
select pg_temp.probe('seller accepts offer1', $q$select respond_to_offer('offer1','accept')$q$);
select pg_temp.check(
  'accepted conversation shows the accept in its own preview (bug: never touched)',
  (select last_message from conversations where id='chat1')='Offer accepted');
select pg_temp.check(
  'the losing buyer''s offer is declined, not left pending for 48h',
  (select status from offers where id='offer2')='declined');
select pg_temp.check(
  'the losing buyer is told in their own chat, not left silent',
  exists(select 1 from messages where conversation_id='chat2' and type='system'
    and body='This item was reserved for another offer'));
select pg_temp.check(
  'the losing buyer''s chat preview reflects it, so it is not stuck on the old offer',
  (select last_message from conversations where id='chat2')='This item was reserved for another offer');

select pg_temp.probe(
  'seller marks target2 sold directly, without ever accepting an offer',
  $q$update listings set status='sold' where id='target2'$q$);
select pg_temp.check(
  'a listing sold outside the offer flow still declines its pending offers',
  (select status from offers where id='offer4')='declined');
select pg_temp.check(
  'that buyer is told their offer died with the direct sale, not left with a dead Accept button',
  exists(select 1 from messages where conversation_id='chat4' and type='system' and body='This item was sold'));

table checks;
do $$ declare failures text; begin
select string_agg(label||' ['||actual||']', E'\n') into failures from checks where not passed;
if failures is not null then raise exception E'Offer lifecycle regressions:\n%',failures; end if;
end $$;
select count(*)||' offer lifecycle checks passed' as result from checks;
rollback;
