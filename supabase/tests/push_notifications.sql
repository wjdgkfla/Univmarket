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
('target','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','A desk lamp','Barely used.');
insert into conversations(id,listing_id,buyer_id,seller_id) values
('chat','target','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002');

create temp table token as
select decrypted_secret as value from vault.decrypted_secrets where name='push_notification_token';
grant select on token to service_role;
select pg_temp.check('a random push notification token was generated',
 (select length(value) from token) = 72);
create temp table queued as select count(*) as n from net.http_request_queue;

-- No project URL yet (local/CI default): the message still logs a
-- notification row (that part never depended on push being configured),
-- but nothing is queued to actually deliver it.
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select create_message('chat','Is this still available?');
reset role;
select pg_temp.check('a message still logs a notification row without push configured',
 exists(select 1 from notifications where user_id='20000000-0000-0000-0000-000000000002'
   and body='Is this still available?'));
select pg_temp.check('no project URL, no push call',
 (select count(*) from net.http_request_queue) = (select n from queued));

select vault.create_secret('https://example.test','project_url')
where not exists (select 1 from vault.secrets where name='project_url');
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select create_message('chat','Second message, no device yet');
reset role;
select pg_temp.check('a new notification queues one call to send-push',
 (select count(*) from net.http_request_queue) = (select n from queued) + 1
 and exists(select 1 from net.http_request_queue
   where url = 'https://example.test/functions/v1/send-push'
     and headers->>'x-push-token' = (select value from token)));

set local role service_role;
select pg_temp.check('no registered device means nothing to send',
 push_notification_details((select value from token),
   (select id from notifications where body='Second message, no device yet')) is null);
reset role;

-- Register the recipient's device, then a text message resolves to a
-- notification naming the sender and carrying the chat's deep link.
update profiles set fcm_token='device-token-1' where id='20000000-0000-0000-0000-000000000002';
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select create_message('chat','Third message, now with a device');
reset role;
set local role service_role;
create temp table text_push as select push_notification_details(
  (select value from token),
  (select id from notifications where body='Third message, now with a device')
) as d;
select pg_temp.check('a text message notifies the recipient''s device with the sender''s name',
 (select d->>'title' from text_push)='Buyer sent a message');
select pg_temp.check('the body previews the message',
 (select d->>'body' from text_push)='Third message, now with a device');
select pg_temp.check('the link opens the right chat',
 (select d->>'link' from text_push)='/chat/chat');
select pg_temp.check('the registered device token is included',
 (select d->>'token' from text_push)='device-token-1');
reset role;

-- An offer names the listing instead of echoing the offer body.
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select send_offer('chat','cash',15,'{}');
reset role;
set local role service_role;
-- Every insert in this test runs in the same transaction, so created_at is
-- identical across all of them (Postgres's now() is transaction-stable) —
-- order by it can't pick out "the latest" one. type='offer' is unique here.
create temp table offer_push as select push_notification_details(
  (select value from token),
  (select id from notifications where type='offer')
) as d;
select pg_temp.check('an offer notification names the listing, not "Sent an offer"',
 (select d->>'title' from offer_push)='Buyer sent an offer'
 and (select d->>'body' from offer_push)='A desk lamp');
reset role;

-- The recipient turning off "messages" silences a text but not an offer.
insert into notification_preferences(user_id,messages,offers) values
('20000000-0000-0000-0000-000000000002',false,true);
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select create_message('chat','Fourth message, messages turned off');
reset role;
select pg_temp.check('a disabled category logs no notification at all',
 not exists(select 1 from notifications where body='Fourth message, messages turned off'));

-- Authorization: only the trigger's own token unlocks this function.
set local role anon;
select pg_temp.probe('anonymous cannot read push details',
$q$select push_notification_details((select value from token),'x')$q$,'42501');
set local role authenticated;
select pg_temp.probe('students cannot read push details',
$q$select push_notification_details((select value from token),'x')$q$,'42501');
set local role service_role;
select pg_temp.probe('service key without the right token is refused',
$q$select push_notification_details('wrong-token','x')$q$,'42501');
reset role;

table checks;
do $$ declare failures text; begin
select string_agg(label||' ['||actual||']', E'\n') into failures from checks where not passed;
if failures is not null then raise exception E'Push notification regressions:\n%',failures; end if;
end $$;
select count(*)||' push notification checks passed' as result from checks;
rollback;
