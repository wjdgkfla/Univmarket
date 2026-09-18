create table conversations (
  id                 text primary key default gen_random_uuid()::text,
  listing_id         text not null references listings(id),
  buyer_id           text not null references profiles(id),
  seller_id          text not null references profiles(id),
  last_message       text not null default '',
  buyer_last_read_at timestamptz,
  seller_last_read_at timestamptz,
  is_active          bool not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (listing_id, buyer_id)
);

create table offers (
  id              text primary key default gen_random_uuid()::text,
  listing_id      text not null references listings(id),
  conversation_id text not null references conversations(id),
  from_user_id    text not null references profiles(id),
  to_user_id      text not null references profiles(id),
  kind            text not null check (kind in ('cash','trade','trade_plus_cash')),
  cash_amount     numeric(10,2) not null default 0 check (cash_amount >= 0),
  status          text not null default 'pending'
                  check (status in ('pending','accepted','declined','withdrawn','superseded','expired')),
  parent_offer_id text references offers(id),
  expires_at      timestamptz,
  created_at      timestamptz not null default now()
);

create table offer_items (
  offer_id           text not null references offers(id) on delete cascade,
  offered_listing_id text not null references listings(id),
  primary key (offer_id, offered_listing_id)
);

create table messages (
  id              text primary key default gen_random_uuid()::text,
  conversation_id text not null references conversations(id),
  from_user_id    text not null references profiles(id),
  to_user_id      text not null references profiles(id),
  body            text not null check (length(body) between 1 and 2000),
  type            text not null default 'text' check (type in ('text','offer','system')),
  offer_id        text references offers(id),
  created_at      timestamptz not null default now()
);

create index messages_conversation_created_idx on messages (conversation_id, created_at);
create index offers_listing_idx on offers (listing_id);
create index offers_conversation_idx on offers (conversation_id);
