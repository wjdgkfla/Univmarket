-- Preserve rows and existing RPCs; restrict direct client writes.
revoke truncate, references, trigger on all tables in schema public from public, anon, authenticated;
revoke all privileges on public.profiles from public, anon, authenticated;
grant select on public.profiles to authenticated;
grant update (display_name, bio) on public.profiles to authenticated;
-- The automatically updatable view must not provide a second write route.
revoke all privileges on public.public_profiles from public, anon, authenticated;
grant select on public.public_profiles to authenticated;
-- Profile creation remains exclusively through the existing owner-executed RPC.
-- Verified membership and the remaining RPC authorization are a separate migration.
notify pgrst, 'reload schema';
