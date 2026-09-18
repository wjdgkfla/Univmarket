alter function is_active_user(text) set search_path = public;
alter function increment_view_count(text) set search_path = public;
alter function is_blocked(text, text) set search_path = public;
alter function start_conversation(text) set search_path = public;
alter function create_message(text, text) set search_path = public;
alter function send_offer(text, text, numeric, text[]) set search_path = public;
alter function respond_to_offer(text, text) set search_path = public;

drop view public_profiles;
create view public_profiles with (security_invoker = true) as
  select id, display_name, profile_image_url, reputation_score,
         completed_transaction_count, joined_at, university_id, home_campus_id
  from profiles where account_state != 'deleted';
grant select on public_profiles to authenticated, anon;
