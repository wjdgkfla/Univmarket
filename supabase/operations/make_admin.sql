-- Hosted project only. Makes a verified student a moderator for their own
-- university: they get "Review reports" in Profile after reopening the app.
-- Clients can never write profiles.role, so this runs as the project owner
-- (Supabase SQL editor). Replace the email, run, and check one row changed.
update public.profiles p
set role = 'admin'
from auth.users u
where u.id::text = p.id
  and lower(u.email) = lower('moderator@gmu.edu')
  and p.account_state = 'active'
returning p.id, p.display_name, p.university_id, p.role;

-- To remove moderator access later:
-- update public.profiles p set role = 'student' from auth.users u
-- where u.id::text = p.id and lower(u.email) = lower('moderator@gmu.edu');
