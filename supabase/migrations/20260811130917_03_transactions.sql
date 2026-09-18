create table transactions (
  id                  text primary key default gen_random_uuid()::text,
  listing_id          text not null references listings(id),
  offer_id            text references offers(id),
  buyer_id            text not null references profiles(id),
  seller_id           text not null references profiles(id),
  kind                text not null check (kind in ('sale','trade')),
  agreed_price        numeric(10,2),
  status              text not null default 'reserved'
                      check (status in ('reserved','meetup_scheduled','completed','cancelled','disputed')),
  meetup_zone_id      uuid references pickup_zones(id),
  meetup_time         timestamptz,
  meetup_proposed_by  text references profiles(id),
  buyer_confirmed_at  timestamptz,
  seller_confirmed_at timestamptz,
  completed_at        timestamptz,
  cancelled_at        timestamptz,
  cancelled_by        text,
  cancellation_reason text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create table transaction_listings (
  transaction_id text not null references transactions(id) on delete cascade,
  listing_id     text not null references listings(id),
  role           text not null check (role in ('target','offered')),
  -- Denormalized from transactions.status (kept in sync by the RPCs that
  -- change transaction state) so "at most one active transaction per
  -- listing" can be a plain partial unique index — Postgres partial
  -- indexes can't reference a subquery, only columns on the row itself.
  is_active      bool not null default true,
  primary key (transaction_id, listing_id)
);

create unique index one_active_transaction_per_listing
  on transaction_listings (listing_id)
  where is_active;
