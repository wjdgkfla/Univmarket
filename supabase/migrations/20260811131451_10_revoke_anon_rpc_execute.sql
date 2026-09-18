revoke execute on function is_active_user(text) from anon;
revoke execute on function increment_view_count(text) from anon;
revoke execute on function is_blocked(text, text) from anon;
revoke execute on function start_conversation(text) from anon;
revoke execute on function create_message(text, text) from anon;
revoke execute on function send_offer(text, text, numeric, text[]) from anon;
revoke execute on function respond_to_offer(text, text) from anon;
