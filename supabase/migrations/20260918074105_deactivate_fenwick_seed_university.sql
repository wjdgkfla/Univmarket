-- Launch is GMU and GWU only. Hide the legacy Fenwick seed school; its test
-- profiles and listings stay in place but can no longer be reached.
update public.universities set active = false where slug = 'fenwick';
