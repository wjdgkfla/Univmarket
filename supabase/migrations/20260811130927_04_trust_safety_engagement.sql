create table ratings (
  id             text primary key default gen_random_uuid()::text,
  transaction_id text not null references transactions(id),
  reviewer_id    text not null references profiles(id),
  reviewee_id    text not null references profiles(id),
  score          smallint not null check (score in (1,-1)),
  tags           text[] not null default '{}',
  created_at     timestamptz not null default now(),
  unique (reviewer_id, transaction_id)
);

create table reports (
  id               text primary key default gen_random_uuid()::text,
  reporter_id      text not null references profiles(id),
  reported_user_id text not null references profiles(id),
  listing_id       text references listings(id),
  transaction_id   text references transactions(id),
  reason           text not null,
  notes            text,
  status           text not null default 'open' check (status in ('open','reviewed','resolved')),
  created_at       timestamptz not null default now()
);

create table blocks (
  blocker_id text not null references profiles(id),
  blocked_id text not null references profiles(id),
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table favorites (
  user_id    text references profiles(id),
  listing_id text references listings(id),
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create table saved_searches (
  id                text primary key default gen_random_uuid()::text,
  user_id           text not null references profiles(id),
  label             text not null,
  query             text not null default '',
  filters           jsonb not null default '{}',
  normalized_key    text not null,
  last_notified_at  timestamptz,
  created_at        timestamptz not null default now(),
  unique (user_id, normalized_key)
);

create table price_watches (
  user_id          text references profiles(id),
  listing_id       text references listings(id),
  last_seen_price  numeric(10,2) not null,
  created_at       timestamptz not null default now(),
  primary key (user_id, listing_id)
);
