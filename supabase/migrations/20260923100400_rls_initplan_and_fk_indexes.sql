-- Performance advisors: index the foreign keys the app filters on, and let
-- Postgres evaluate auth.uid() once per statement instead of once per row.

create index if not exists conversations_buyer_idx on public.conversations (buyer_id);
create index if not exists conversations_seller_idx on public.conversations (seller_id);
create index if not exists messages_from_user_idx on public.messages (from_user_id);
create index if not exists messages_to_user_idx on public.messages (to_user_id);
create index if not exists offers_from_user_idx on public.offers (from_user_id);
create index if not exists offers_to_user_idx on public.offers (to_user_id);
create index if not exists favorites_listing_idx on public.favorites (listing_id);
create index if not exists listings_seller_idx on public.listings (seller_id);

-- Wrap every bare auth.uid() in public policies as (select auth.uid()).
-- The expression is otherwise unchanged, so each policy keeps its meaning;
-- calls already wrapped (deparsed as "SELECT auth.uid()") are left alone.
do $$
declare
  p record;
  bare constant text := '(?<!SELECT )auth\.uid\(\)';
  q text;
  c text;
begin
  for p in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (qual ~ bare or with_check ~ bare)
  loop
    q := regexp_replace(p.qual, bare, '(select auth.uid())', 'g');
    c := regexp_replace(p.with_check, bare, '(select auth.uid())', 'g');
    execute format('alter policy %I on %I.%I', p.policyname, p.schemaname, p.tablename)
      -- format() renders NULL as '', so test for absent clauses explicitly.
      || case when q is null then '' else format(' using (%s)', q) end
      || case when c is null then '' else format(' with check (%s)', c) end;
  end loop;

  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and (qual ~ bare or with_check ~ bare)
  ) then
    raise exception 'auth.uid() is still evaluated per row in a public policy';
  end if;
end $$;
