create table notifications (
  id         text primary key default gen_random_uuid()::text,
  user_id    text not null references profiles(id),
  type       text not null,
  title      text not null,
  body       text not null,
  link       text,
  meta       jsonb,
  is_read    bool not null default false,
  created_at timestamptz not null default now()
);

create table notification_preferences (
  user_id               text primary key references profiles(id),
  messages              bool not null default true,
  offers                bool not null default true,
  meetups               bool not null default true,
  saved_search_matches  bool not null default true,
  price_drops           bool not null default true,
  marketing             bool not null default false
);

create table device_push_tokens (
  id           text primary key default gen_random_uuid()::text,
  user_id      text not null references profiles(id),
  platform     text not null check (platform in ('ios','android')),
  token        text not null,
  created_at   timestamptz not null default now(),
  last_seen_at timestamptz,
  unique (user_id, token)
);

create table outbox_events (
  id           bigint generated always as identity primary key,
  kind         text not null,
  payload      jsonb not null,
  created_at   timestamptz not null default now(),
  processed_at timestamptz,
  attempts     int not null default 0
);

create table admin_activity (
  id            text primary key default gen_random_uuid()::text,
  actor_user_id text not null references profiles(id),
  action        text not null,
  target_type   text not null,
  target_id     text not null,
  notes         text,
  created_at    timestamptz not null default now()
);

create table analytics_events (
  id         bigint generated always as identity primary key,
  user_id    text,
  event      text not null,
  properties jsonb not null default '{}',
  created_at timestamptz not null default now()
);
