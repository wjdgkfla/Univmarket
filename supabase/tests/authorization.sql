-- Disposable CI database only; probes roll back successful writes.
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
insert into universities(id,slug,name,short_name,active) values
('10000000-0000-0000-0000-000000000001','fenwick','Test A','A',true),
('10000000-0000-0000-0000-000000000002','test-b','Test B','B',true);
insert into university_domains values
('a.test','10000000-0000-0000-0000-000000000001'),('b.test','10000000-0000-0000-0000-000000000002');
insert into campuses(id,university_id,slug,name) values
('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','main','Main A'),
('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','main','Main B');
insert into pickup_zones(id,campus_id,slug,name) values
('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','library','Library A'),
('40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','library','Library B');
insert into auth.users(id,email,email_confirmed_at,is_anonymous,raw_user_meta_data)
select ('20000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
'user'||n||case when n in (3,6,7) then '@b.test' when n=8 then '@unapproved.test' else '@a.test' end,
case when n=5 then null else now() end,n=9,
'{"university_id":"10000000-0000-0000-0000-000000000001","role":"admin","email_verified":true}'::jsonb
from generate_series(1,10) n;
insert into profiles(id,university_id,home_campus_id,display_name,account_state)
select '20000000-0000-0000-0000-'||lpad(n::text,12,'0'),
('10000000-0000-0000-0000-'||lpad(case when n=3 then '2' else '1' end,12,'0'))::uuid,
('30000000-0000-0000-0000-'||lpad(case when n=3 then '2' else '1' end,12,'0'))::uuid,
'Test '||n,case when n=4 then 'suspended' else 'active' end
from generate_series(1,9) n where n not in (6,8);
insert into listings(id,seller_id,university_id,campus_id,pickup_zone_id,title,description) values
('target','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','Target','Test target'),
('trade','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','Trade','Test trade'),
('foreign','20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','Foreign','Test foreign');
insert into conversations(id,listing_id,buyer_id,seller_id) values
('chat','target','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002'),
('cross-chat','target','20000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002');
insert into offers(id,listing_id,conversation_id,from_user_id,to_user_id,kind,cash_amount,expires_at) values
('offer','target','chat','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','cash',10,now()+interval '1 day'),
('counter','target','chat','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','cash',15,now()+interval '1 day');
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000006';
select pg_temp.probe('new profile uses confirmed domain not Fenwick or metadata',
$q$do $b$ declare p profiles; begin p:=ensure_profile('New student');
if p.university_id <> '10000000-0000-0000-0000-000000000002' or p.role <> 'student'
or p.home_campus_id <> '30000000-0000-0000-0000-000000000002' then raise exception 'wrong profile assignment'; end if;
end $b$;$q$);

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000005';
select pg_temp.probe('unconfirmed email rejected despite metadata',$q$select ensure_profile()$q$,'42501');

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000007';
select pg_temp.probe('existing mismatched membership rejected',$q$select ensure_profile()$q$,'42501');

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000008';
select pg_temp.probe('unapproved domain rejected',$q$select ensure_profile()$q$,'42501');

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000009';
select pg_temp.probe('anonymous auth user rejected',$q$select ensure_profile()$q$,'42501');

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select pg_temp.probe('confirmed owner bootstraps',$q$select ensure_profile()$q$,'allowed');
select pg_temp.probe('owner edits available listing',$q$do $b$ begin update listings set title='Updated title' where id='trade'; if not found then raise exception 'owner edit failed'; end if; end $b$;$q$,'allowed');
select pg_temp.probe('cross university listing insert denied',$q$insert into listings(seller_id,university_id,campus_id,title,description) values(auth.uid()::text,'10000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','Bad','Bad')$q$,'42501');
select pg_temp.probe('foreign pickup zone denied',$q$update listings set pickup_zone_id='40000000-0000-0000-0000-000000000002' where id='trade'$q$,'42501');
select pg_temp.probe('moderation field not client writable',$q$update listings set moderation_state='visible' where id='trade'$q$,'42501');
select pg_temp.probe('university reassignment not client writable',$q$update listings set university_id='10000000-0000-0000-0000-000000000002' where id='trade'$q$,'42501');
select pg_temp.probe('counter forgery not client writable',$q$update listings set view_count=999 where id='trade'$q$,'42501');
select pg_temp.probe('same university message succeeds',$q$select create_message('chat','Hello')$q$,'allowed');
select pg_temp.probe('cross university conversation denied',$q$select start_conversation('foreign')$q$,'42501');
select pg_temp.probe('foreign view increment denied',$q$select increment_view_count('foreign')$q$,'42501');
select pg_temp.probe('valid cash offer succeeds',$q$select send_offer('chat','cash',10,'{}')$q$,'allowed');
select pg_temp.probe('valid trade offer reserves both listings atomically',
$q$do $b$ declare offer_id text; begin
 offer_id:=send_offer('chat','trade',0,array['trade']);
 perform set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',true);
 perform respond_to_offer(offer_id,'accept');
 if (select count(*) from listings where id in ('target','trade') and status='reserved')<>2
 or (select count(*) from transaction_listings tl join transactions t on t.id=tl.transaction_id where t.offer_id=offer_id and tl.is_active)<>2 then
 raise exception 'Trade did not reserve both listings'; end if;
end $b$;$q$,'allowed');
select pg_temp.probe('own available listing can be marked sold',
$q$do $b$ begin update listings set status='sold' where id='trade';
 if not found then raise exception 'Owner sale update failed'; end if; end $b$;$q$,'allowed');
select pg_temp.probe('direct reserved status denied',
$q$update listings set status='reserved' where id='trade'$q$,'42501');
select pg_temp.probe('own listing view counter can increment',
$q$do $b$ begin perform increment_view_count('trade');
 if (select view_count from listings where id='trade')<>1 then raise exception 'Counter not incremented'; end if; end $b$;$q$,'allowed');
select pg_temp.probe('unrelated block relationship cannot be queried',
$q$select is_blocked('20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000003')$q$,'42501');
select pg_temp.probe('duplicate trade item rejected',
$q$select send_offer('chat','trade',0,array['trade','trade'])$q$,'22023');
select pg_temp.probe('null trade array rejected',
$q$select send_offer('chat','trade',0,null)$q$,'22023');
select pg_temp.probe('blank message rejected',
$q$select create_message('chat','   ')$q$,'22023');
select pg_temp.probe('cash cannot smuggle another owners trade listing',$q$select send_offer('chat','cash',10,array['foreign'])$q$,'22023');
select pg_temp.probe('empty trade rejected',$q$select send_offer('chat','trade',0,'{}')$q$,'22023');
select pg_temp.probe('null kind rejected',$q$select send_offer('chat',null,10,'{}')$q$,'22023');
select pg_temp.probe('sender cannot accept own offer',$q$select respond_to_offer('offer','accept')$q$,'42501');
select pg_temp.probe('counteroffer keeps actual buyer and seller',$q$do $b$ begin perform respond_to_offer('counter','accept'); if not exists(select 1 from transactions where offer_id='counter' and seller_id='20000000-0000-0000-0000-000000000002' and buyer_id='20000000-0000-0000-0000-000000000001') then raise exception 'buyer and seller reversed'; end if; end $b$;$q$,'allowed');

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000003';
select pg_temp.probe('legacy cross university chat cannot send',$q$select create_message('cross-chat','Hello')$q$,'42501');
select pg_temp.probe('legacy cross university chat cannot offer',$q$select send_offer('cross-chat','cash',10,'{}')$q$,'42501');

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
select pg_temp.probe('recipient can accept',$q$select respond_to_offer('offer','accept')$q$,'allowed');
reset role;
insert into blocks(blocker_id,blocked_id) values ('20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002');
set local role authenticated;
select pg_temp.probe('blocked acceptance denied',$q$select respond_to_offer('offer','accept')$q$,'42501');
select pg_temp.probe('blocked message denied',$q$select create_message('chat','Hello')$q$,'42501');
select pg_temp.probe('blocked offer denied',$q$select send_offer('chat','cash',10,'{}')$q$,'42501');
reset role;
delete from blocks;
update profiles set account_state='suspended' where id='20000000-0000-0000-0000-000000000002';
set local role authenticated;
select pg_temp.probe('suspended recipient cannot accept',$q$select respond_to_offer('offer','accept')$q$,'42501');

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select pg_temp.probe('cannot message suspended counterparty',$q$select create_message('chat','Hello')$q$,'42501');
reset role;
update profiles set account_state='active' where id='20000000-0000-0000-0000-000000000002';
update offers set expires_at=now()-interval '1 hour' where id='offer';
set local role authenticated;

set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000002';
select pg_temp.probe('expired offer cannot be accepted',$q$select respond_to_offer('offer','accept')$q$,'22023');
reset role;
update offers set expires_at=now()+interval '1 day' where id='offer';
update listings set moderation_state='hidden' where id='target';
set local role authenticated;
select pg_temp.probe('hidden listing cannot be reserved',$q$select respond_to_offer('offer','accept')$q$,'42501');
reset role;
set local role anon;
set local request.jwt.claim.sub='';
select pg_temp.probe('unauthenticated RPC denied',$q$select ensure_profile()$q$,'42501');
reset role;
-- Membership is checked from current database state, not a cached token.
update auth.users set email='changed@unapproved.test' where id='20000000-0000-0000-0000-000000000001';
set local role authenticated;
set local request.jwt.claim.sub='20000000-0000-0000-0000-000000000001';
select pg_temp.probe('email change immediately denies existing member',
$q$select ensure_profile()$q$,'42501');
select pg_temp.probe('email change also removes direct listing reads',
$q$do $b$ begin if exists(select 1 from listings) then raise exception 'Unverified member read listings'; end if; end $b$;$q$,'allowed');
select pg_temp.probe('email change removes direct profile editing',
$q$do $b$ begin update profiles set display_name='Bad edit' where id=auth.uid()::text;
 if found then raise exception 'Unverified member edited profile'; end if; end $b$;$q$,'allowed');
reset role;
table checks;
do $$ declare failures text; begin
select string_agg(label||' ['||actual||']', E'\n') into failures from checks where not passed;
if failures is not null then raise exception E'Authorization regressions:\n%',failures; end if;
end $$;
select count(*)||' authorization checks passed' as result from checks;
rollback;
