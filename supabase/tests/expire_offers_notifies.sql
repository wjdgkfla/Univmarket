-- Disposable CI database only; every fixture and write is rolled back.
-- Covers 20260923150000_expire_offers_notifies.sql (bug B4). The original
-- expiry behavior itself (which offers get expired, that clients can't call
-- it, that the cron job exists) is already covered by audit_hardening.sql;
-- this only covers what's new — telling both sides when it happens.
begin;
create temp table checks(label text, passed boolean, actual text);
grant all on checks to authenticated, anon, service_role;
create function pg_temp.check(label text, passed boolean) returns void
language sql as $$ insert into checks values(label, passed, passed::text) $$;

insert into universities(id,slug,name,short_name,active) values
('10000000-0000-0000-0000-000000000001','test-a','Test A','A',true);
insert into university_domains values ('a.test','10000000-0000-0000-0000-000000000001');
insert into campuses(id,university_id,slug,name) values
('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','main','Main A');
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
('20000000-0000-0000-0000-000000000001','buyer@a.test',now(),false),
('20000000-0000-0000-0000-000000000002','seller@a.test',now(),false);
insert into profiles(id,university_id,home_campus_id,display_name) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Buyer'),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Seller');
insert into listings(id,seller_id,university_id,campus_id,title,description) values
('target','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Target','Expiring offer');
insert into conversations(id,listing_id,buyer_id,seller_id) values
('chat','target','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002');
insert into offers(id,listing_id,conversation_id,from_user_id,to_user_id,kind,cash_amount,expires_at) values
('offer','target','chat','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','cash',10,now()-interval '1 minute');

select pg_temp.check('the stale offer expires', app_private.expire_offers()=1);
select pg_temp.check('the offer is now expired',
 (select status from offers where id='offer')='expired');
select pg_temp.check('the buyer is told their offer expired, not left silent',
 exists(select 1 from messages where conversation_id='chat' and type='system' and body='Offer expired'));
select pg_temp.check('the conversation preview reflects it',
 (select last_message from conversations where id='chat')='Offer expired');
select pg_temp.check('a second run has nothing left to expire',
 app_private.expire_offers()=0);

table checks;
do $$ declare failures text; begin
select string_agg(label||' ['||actual||']', E'\n') into failures from checks where not passed;
if failures is not null then raise exception E'Offer expiry regressions:\n%',failures; end if;
end $$;
select count(*)||' offer expiry checks passed' as result from checks;
rollback;
