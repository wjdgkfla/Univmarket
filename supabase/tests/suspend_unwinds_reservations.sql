-- Disposable CI database only; every fixture and write is rolled back.
-- Covers 20260923151000_suspend_unwinds_reservations.sql (bug B5).
-- admin_resolve_report's other behavior (authorization, hide_listing,
-- dismiss, the admin_activity log) is already covered by
-- admin_report_review.sql; this only covers what's new.
begin;
create temp table checks(label text, passed boolean, actual text);
grant all on checks to authenticated, anon;
create function pg_temp.check(label text, passed boolean) returns void
language sql as $$ insert into checks values(label, passed, passed::text) $$;

insert into universities(id,slug,name,short_name,active) values
('10000000-0000-0000-0000-000000000001','test-a','Test A','A',true);
insert into university_domains values ('a.test','10000000-0000-0000-0000-000000000001');
insert into campuses(id,university_id,slug,name) values
('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','main','Main A');
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
('20000000-0000-0000-0000-000000000001','admin@a.test',now(),false),
('20000000-0000-0000-0000-000000000002','suspended@a.test',now(),false),
('20000000-0000-0000-0000-000000000003','buyer@a.test',now(),false),
('20000000-0000-0000-0000-000000000004','otherseller@a.test',now(),false),
('20000000-0000-0000-0000-000000000005','offerrecipient@a.test',now(),false);
insert into profiles(id,university_id,home_campus_id,display_name,role) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Admin','admin'),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Suspended','student'),
('20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Buyer','student'),
('20000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Other seller','student'),
('20000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Offer recipient','student');

-- Reserved as seller: the buyer must get their listing back.
insert into listings(id,seller_id,university_id,campus_id,title,description,status) values
('own-item','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Own item','Reserved to a buyer.','reserved');
insert into conversations(id,listing_id,buyer_id,seller_id) values
('conv-own','own-item','20000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002');
insert into offers(id,listing_id,conversation_id,from_user_id,to_user_id,kind,cash_amount,status,expires_at) values
('offer-own','own-item','conv-own','20000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002','cash',10,'accepted',now()+interval '1 day');
insert into transactions(id,listing_id,offer_id,buyer_id,seller_id,kind,agreed_price,status) values
('t-own','own-item','offer-own','20000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002','sale',10,'reserved');
insert into transaction_listings(transaction_id,listing_id,role,is_active) values
('t-own','own-item','target',true);

-- Reserved as buyer: the seller must get their listing back.
insert into listings(id,seller_id,university_id,campus_id,title,description,status) values
('their-item','20000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Their item','Reserved by the suspended student.','reserved');
insert into conversations(id,listing_id,buyer_id,seller_id) values
('conv-their','their-item','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000004');
insert into offers(id,listing_id,conversation_id,from_user_id,to_user_id,kind,cash_amount,status,expires_at) values
('offer-their','their-item','conv-their','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000004','cash',20,'accepted',now()+interval '1 day');
insert into transactions(id,listing_id,offer_id,buyer_id,seller_id,kind,agreed_price,status) values
('t-their','their-item','offer-their','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000004','sale',20,'reserved');
insert into transaction_listings(transaction_id,listing_id,role,is_active) values
('t-their','their-item','target',true);

-- A pending offer elsewhere, unrelated to either reservation.
insert into listings(id,seller_id,university_id,campus_id,title,description) values
('offer-item','20000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Offer item','Still available.');
insert into conversations(id,listing_id,buyer_id,seller_id) values
('conv-offer','offer-item','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000005');
insert into offers(id,listing_id,conversation_id,from_user_id,to_user_id,kind,cash_amount,expires_at) values
('offer-pending','offer-item','conv-offer','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000005','cash',15,now()+interval '1 day');

insert into reports(id,reporter_id,reported_user_id,reason,status) values
('r1','20000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002','scam','open');

set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select admin_resolve_report('r1','suspend_user');
reset role;

select pg_temp.check('the suspended student is actually suspended',
 (select account_state from profiles where id='20000000-0000-0000-0000-000000000002')='suspended');

select pg_temp.check('their reservation as seller is cancelled by the admin',
 (select status='cancelled' and cancelled_by='20000000-0000-0000-0000-000000000001'
   and cancellation_reason='account suspended' from transactions where id='t-own'));
select pg_temp.check('the buyer gets that listing back on the market',
 (select status from listings where id='own-item')='available');
select pg_temp.check('the (now unwound) transaction_listings row is deactivated',
 not (select is_active from transaction_listings where transaction_id='t-own' and listing_id='own-item'));

select pg_temp.check('their reservation as buyer is also cancelled',
 (select status from transactions where id='t-their')='cancelled');
select pg_temp.check('the other seller gets their listing back on the market',
 (select status from listings where id='their-item')='available');

select pg_temp.check('both unwound reservations tell the other party in their thread',
 (select count(*) from messages where conversation_id in ('conv-own','conv-their')
   and type='system' and body='Reservation cancelled')=2);
select pg_temp.check('both unwound conversations bubble to the top of the inbox',
 (select count(*) from conversations where id in ('conv-own','conv-their')
   and last_message='Reservation cancelled')=2);

select pg_temp.check('a pending offer they''re still a party to elsewhere is withdrawn',
 (select status from offers where id='offer-pending')='withdrawn');
select pg_temp.check('the other side of that offer is told, so Accept/Decline does not just go dead',
 (select count(*) from messages where conversation_id='conv-offer'
   and type='system' and body='Offer withdrawn')=1);
select pg_temp.check('that conversation bubbles to the top of the inbox too',
 (select last_message from conversations where id='conv-offer')='Offer withdrawn');

select pg_temp.check('their own listing is hidden (declining any pending offers on it, for free, via the trigger)',
 (select moderation_state from listings where id='own-item')='hidden');

select pg_temp.check('the report is resolved',
 (select status from reports where id='r1')='resolved');

table checks;
do $$ declare failures text; begin
select string_agg(label||' ['||actual||']', E'\n') into failures from checks where not passed;
if failures is not null then raise exception E'Suspend-unwind regressions:\n%',failures; end if;
end $$;
select count(*)||' suspend-unwind checks passed' as result from checks;
rollback;
