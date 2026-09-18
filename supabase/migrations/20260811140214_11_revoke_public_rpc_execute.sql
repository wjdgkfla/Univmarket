revoke execute on function is_active_user(text) from public;
revoke execute on function increment_view_count(text) from public;
revoke execute on function is_blocked(text, text) from public;
revoke execute on function start_conversation(text) from public;
revoke execute on function create_message(text, text) from public;
revoke execute on function send_offer(text, text, numeric, text[]) from public;
revoke execute on function respond_to_offer(text, text) from public;
revoke execute on function ensure_profile(text) from public;

grant execute on function start_conversation(text) to authenticated;
grant execute on function create_message(text, text) to authenticated;
grant execute on function send_offer(text, text, numeric, text[]) to authenticated;
grant execute on function respond_to_offer(text, text) to authenticated;
grant execute on function ensure_profile(text) to authenticated;
grant execute on function increment_view_count(text) to authenticated;
